/**
 * ジョブ定義
 */
resource "aws_batch_job_definition" "batch_job_definition" {
  name = local.job_name
  type = "container"
  platform_capabilities = [
    "FARGATE",
  ]

  container_properties = jsonencode({
    environment = [
      for k, v in var.env : {
        name = k
        value = v
      }
    ]
    image = "${var.image_uri}:${var.image_tag}"
    fargatePlatformConfiguration = {
      platformVersion = "1.4.0"
    }
    # ResourceRequirement: https://docs.aws.amazon.com/ja_jp/batch/latest/APIReference/API_ResourceRequirement.html
    resourceRequirements = [
      {
        type = "VCPU"
        value = var.vcpus
      },
      {
        type = "MEMORY"
        value = var.memory
      }
    ],
    jobRoleArn = aws_iam_role.ecs_task_role.arn
    executionRoleArn = aws_iam_role.ecs_task_execution_role.arn

  })
}

/**
 * ステートマシン (Pipeターゲット)
 *
 * ステートメント言語: https://docs.aws.amazon.com/ja_jp/step-functions/latest/dg/concepts-amazon-states-language.html
 *
 * Batch:
 *   https://docs.aws.amazon.com/ja_jp/step-functions/latest/dg/connect-batch.html
 * Lambda:
 *   https://docs.aws.amazon.com/ja_jp/step-functions/latest/dg/connect-lambda.html
 */
// ステートマシン用ロググループ
resource "aws_cloudwatch_log_group" "scheduled_job_log_group" {
  name = "${var.app_name}/${var.stage}/scheduled/${var.batch_name}"
  retention_in_days = 365
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine
resource "aws_sfn_state_machine" "scheduled_job" {
  name = local.job_name
  role_arn = aws_iam_role.batch_sfn_role.arn

  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.scheduled_job_log_group.arn}:*"
    include_execution_data = true
    level = "ALL"
  }

  definition = jsonencode(
    {
      "Comment": "A description of my state machine",
      "StartAt": "ExtractInputParameters",
      "States": {
        // 入力パラメータの抽出
        "ExtractInputParameters": {
          "Type": "Pass",
          "Next": "BatchGroup",
          "Parameters":{
            "metadata": {
              "app_name": var.app_name,
              "stage": var.stage,
              "batch_name": var.batch_name,
              "job_name": local.job_name,
              "command": var.command,
              "vcpus": var.vcpus,
              "memory": var.memory,
              "image_uri": var.image_uri,
              "image_tag": var.image_tag,
              "env": var.env,
            },
            "input.$" : "$"
          },
          // {"metadata": <メタデータ>, "input": <入力パラメータ>} 形式に変換
          "ResultPath": "$"
        },
        // ジョブ実行
        "BatchGroup": {
          "Type": "Parallel",
          "Branches": [
            {
              "StartAt": "Batch",
              "States": {
                // バッチ処理
                "Batch": {
                  "Type": "Task",
                  "Resource": "arn:aws:states:::batch:submitJob.sync",
                  // https://docs.aws.amazon.com/step-functions/latest/dg/connect-batch.html
                  "Parameters": {
                    "JobName": local.job_name,
                    "JobDefinition": "${aws_batch_job_definition.batch_job_definition.arn}",
                    "JobQueue": "${var.batch_job_queue_arn}",
                    // Parameters: https://docs.aws.amazon.com/batch/latest/APIReference/API_SubmitJob.html#Batch-SubmitJob-request-parameters
                    "Parameters": {
                      "sfn_input.$": "$.input"
                    },
                    // ContainerOverrides: https://docs.aws.amazon.com/batch/latest/APIReference/API_ContainerOverrides.html
                    "ContainerOverrides": {
                      "Command": var.command
                    }
                  },
                  // {"metadata": <メタデータ>, "input": <入力パラメータ>, "batch": <バッチ処理の結果>} 形式に変換
                  "ResultPath": "$.batch",
                  "Next": "OnSuccess"
                },
                // 成功ハンドラ
                "OnSuccess": {
                  "Type": "Task",
                  "Resource": "arn:aws:states:::lambda:invoke",
                  "Parameters": {
                    "Payload": {
                      "state.$": "$",  // {"metadata": <メタデータ>, "input": <入力パラメータ>, "batch": <バッチ処理の結果>}
                      "context.$": "$$"  // すべてのコンテキストを渡す
                    },
                    "FunctionName": "${var.success_handler_arn}:$LATEST"
                  },
                  // {"metadata": <メタデータ>, "input": <入力パラメータ>, "batch": <バッチ処理の結果>, "success_handler": <成功ハンドラの結果>} 形式に変換
                  "ResultPath": "$.success_handler",
                  "End": true
                }
              }
            }
          ],
          "Catch": [
            {
              "ErrorEquals": [
                "States.ALL"
              ],
              // {"metadata": <メタデータ>, "input": <入力パラメータ>, "error": <エラー>, ...} 形式に変換
              "ResultPath": "$.error",
              "Next": "ErrorHandler"
            }
          ],
          "End": true
        },
        // エラーハンドラ
        "ErrorHandler": {
          "Type": "Task",
          "Resource": "arn:aws:states:::lambda:invoke",
          "Parameters": {
            "Payload": {
              "state.$": "$",  // すべての入力パラメータを渡す {"metadata": <メタデータ>, "input": <入力パラメータ>, "error": <エラー>, ...}
              "context.$": "$$"  // すべてのコンテキストを渡す
            },
            "FunctionName": "${var.error_handler_arn}:$LATEST"
          },
          // {"metadata": <メタデータ>, "input": <入力パラメータ>, "error": <エラー>, "error_handler": <エラーハンドラの結果>, ...} 形式に変換
          "ResultPath": "$.error_handler",
          "Retry": [
            {
              "ErrorEquals": [
                "Lambda.ServiceException",
                "Lambda.AWSLambdaException",
                "Lambda.SdkClientException"
              ],
              "IntervalSeconds": 2,
              "MaxAttempts": 6,
              "BackoffRate": 2
            }
          ],
          "End": true
        }
      }
    }
  )
}

/**
 * EventBridge scheduler
 */

resource "aws_scheduler_schedule" "this" {
  name       = "${local.job_name}-Scheduler"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  // AWS - EventBridge - スケジュールタイプ: https://docs.aws.amazon.com/ja_jp/scheduler/latest/UserGuide/schedule-types.html
  schedule_expression = var.schedule_expression
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = aws_sfn_state_machine.scheduled_job.arn
    role_arn = aws_iam_role.batch_scheduler_role.arn
    input = jsonencode(var.sfn_input)
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_target_policy,
  ]
}