/**
 * SQS (Pipeソース)
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue.html
 */
resource "aws_sqs_queue" "pipe_source" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-Queue"
  # キューに送信されたメッセージがコンシューマに表示されるまでの時間 (秒)
  delay_seconds = 0
  # 最大メッセージサイズ (バイト)
  max_message_size = 262144 # 256KiB
  # メッセージ保持期間 (秒)
  message_retention_seconds = 604800 # 7 days
  # メッセージ受信待機時間 (秒)
  receive_wait_time_seconds = 0
  # 可視性タイムアウト (秒)
  # コンシューマがこの期間内にメッセージを処理して削除できなかった場合、メッセージは再度キューに表示される。
  visibility_timeout_seconds = 30
  # NOTE: DLQ
}

/**
 * ジョブ定義
 */
resource "aws_batch_job_definition" "batch_job_definition" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-Batch"
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
resource "aws_cloudwatch_log_group" "report_job_log_group" {
  name = "${var.app_name}/${var.stage}/${var.batch_name}"
  retention_in_days = 365
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine
resource "aws_sfn_state_machine" "pipe_target" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}"
  role_arn = aws_iam_role.batch_sfn_role.arn

  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.report_job_log_group.arn}:*"
    include_execution_data = true
    level = "ALL"
  }

  definition = jsonencode(
    {
      "Comment": "A description of my state machine",
      "StartAt": "ExtractInputParameters",
      "States": {
        "ExtractInputParameters": {
          "Type": "Pass",
          "Next": "BatchGroup",
          "Parameters":{
            "Input.$" : "$"
          },
          "ResultPath": "$"
        },
        "BatchGroup": {
          "Type": "Parallel",
          "Branches": [
            {
              "StartAt": "Batch",
              "States": {
                "Batch": {
                  "Type": "Task",
                  "Resource": "arn:aws:states:::batch:submitJob.sync",
                  // https://docs.aws.amazon.com/step-functions/latest/dg/connect-batch.html
                  "Parameters": {
                    "JobName": "${var.app_name}-${var.stage}-${var.batch_name}-Batch",
                    "JobDefinition": "${aws_batch_job_definition.batch_job_definition.arn}",
                    "JobQueue": "${var.batch_job_queue_arn}",
                    // Parameters: https://docs.aws.amazon.com/batch/latest/APIReference/API_SubmitJob.html#Batch-SubmitJob-request-parameters
                    "Parameters": {
                      "queue_input.$": "$.Input[0].body"
                    },
                    // ContainerOverrides: https://docs.aws.amazon.com/batch/latest/APIReference/API_ContainerOverrides.html
                    "ContainerOverrides": {
                      "Command": var.command
                    }
                  },
                  "ResultPath": "$.deploy_job",
                  "Next": "OnSuccess"
                },
                "OnSuccess": {
                  "Type": "Task",
                  "Resource": "arn:aws:states:::lambda:invoke",
                  "ResultPath": "$.Result.successHandler",
                  "Parameters": {
                    "Payload": {
                      "input.$": "$",
                      "context.$": "$$"
                    },
                    "FunctionName": "${var.success_handler_arn}:$LATEST"
                  },
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
              "ResultPath": "$.error",
              "Next": "ErrorHandler"
            }
          ],
          "End": true
        },
        "ErrorHandler": {
          "Type": "Task",
          "Resource": "arn:aws:states:::lambda:invoke",
          "ResultPath": "$.Result.errorHandler",
          "Parameters": {
            "Payload": {
              "input.$": "$",
              "context.$": "$$"
            },
            "FunctionName": "${var.error_handler_arn}:$LATEST"
          },
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
 * EventBridge Pipes
 */

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/pipes_pipe
resource "aws_pipes_pipe" "batch_pipe" {
  name       = "${var.app_name}-${var.stage}-${var.batch_name}-BatchPipe"
  role_arn   = aws_iam_role.batch_pipes_role.arn
  source     = aws_sqs_queue.pipe_source.arn
  target     = aws_sfn_state_machine.pipe_target.arn

  source_parameters {
    sqs_queue_parameters {
      batch_size = 1
    }
  }

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }


  depends_on = [
    aws_iam_role_policy_attachment.attach_source_policy,
    aws_iam_role_policy_attachment.attach_target_policy,
  ]
}
