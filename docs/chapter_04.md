Chapter4 オンデマンドジョブ
---
[READMEに戻る](../README.md)

# ■ 1. 作るもの

job_baseモジュールで作成したコンピューティング環境で動作するAWS Batchと、AWS Batch, lambdaを一連の処理として定義するStepFunctions、StepFunctionsをキックするためのSQSの作成を行います。  

オンデマンドジョブは、Webアプリから好きなときに起動できるジョブという位置づけです。

<img src="img/04/drawio/architecture.drawio.png" width="900px">

# ■ 2. on_demand_jobモジュールの作成

## 1. ファイルの作成

`on_demand_job` モジュールを定義します。

```bash
ENV_NAME="your_name"
mkdir -p ${CONTAINER_PROJECT_ROOT}/terraform/modules/on_demand_job
touch ${CONTAINER_PROJECT_ROOT}/terraform/modules/on_demand_job/{main.tf,variables.tf,outputs.tf,iam.tf}
```

## 2. 入力値・出力値の定義

`terraform/modules/on_demand_job/variables.tf`

```hcl
variable "account_id" {}
variable "app_name" {}
variable "stage" {}

// Batchの名前
variable "batch_name" {}

// Batch に設定する環境変数
variable "env" { type = map }

// Batchのジョブキュー
variable "batch_job_queue_arn" {}

// Batchで利用するイメージのURI
variable "image_uri" {}

// Batchで利用するイメージのタグ
variable "image_tag" {}

// Batchの実行コマンド
variable "command" { type = list(string) }

// Stepfunctionsで成功処理を行うLambda関数
variable "success_handler_arn" {}

// Stepfunctionsでエラー処理を行うLambda関数
variable "error_handler_arn" {}

// Batchで利用するvCPU数
variable "vcpus" {
  type=string
  default="1"
}

// Batchで利用するメモリサイズ
variable "memory" {
  type=string
  default="2048"
}

locals {
  job_name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob"
}
```

`terraform/modules/on_demand_job/outputs.tf`

```hcl
output "queue_url" {
  value = aws_sqs_queue.pipe_source.url
}

output "queue_arn" {
  value = aws_sqs_queue.pipe_source.arn
}

```

## 3. リソース定義

`terraform/modules/on_demand_job/main.tf`

```hcl
/**
 * SQS (Pipeソース)
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue.html
 */
resource "aws_sqs_queue" "pipe_source" {
  name = "${local.job_name}-Queue"
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
resource "aws_cloudwatch_log_group" "on_demand_job_log_group" {
  name = "${var.app_name}/${var.stage}/on_demand/${var.batch_name}"
  retention_in_days = 365
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine
resource "aws_sfn_state_machine" "on_demand_job" {
  name = local.job_name
  role_arn = aws_iam_role.batch_sfn_role.arn

  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.on_demand_job_log_group.arn}:*"
    include_execution_data = true
    level = "ALL"
  }

  definition = jsonencode(
    {
      "Comment": "A description of my state machine",
      "StartAt": "ExtractInputParameters",
      "States": {
        // 入力パラメータの抽出
        // # 入力パラメータはSQSからのメッセージで配列形式となるが、 aws_pipes_pipe の
        //   source_parameters.sqs_queue_parameters.batch_size が 1 であるため、要素数は1である
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
                      // SQSメッセージの先頭要素のbodyを取得
                      "sqs_message_body.$": "$.input[0].body"
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
 * EventBridge Pipes
 */

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/pipes_pipe
resource "aws_pipes_pipe" "batch_pipe" {
  name       = "${local.job_name}-Pipe"
  role_arn   = aws_iam_role.batch_pipes_role.arn
  source     = aws_sqs_queue.pipe_source.arn
  target     = aws_sfn_state_machine.on_demand_job.arn

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

```

`terraform/modules/on_demand_job/iam.tf`

```hcl
/*******************************
 * ECSタスク実行ロール
 *******************************/
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-EcsTaskExeRole"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_exec_role_policy.json
}

data "aws_iam_policy_document" "assume_ecs_task_exec_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_ecs_task_exec_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/*******************************
 * ECSタスクロール
 *******************************/
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-EcsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role_policy.json
}

data "aws_iam_policy_document" "assume_ecs_task_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_task_role_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-EcsTaskRolePolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource" = [
          "*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "sns:Publish"
        ],
        "Resource": [
          "*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource": [
          "arn:aws:secretsmanager:ap-northeast-1:${var.account_id}:secret:/${var.app_name}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ecs_task_role_policy" {
  role = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}

/**
 * EventBridge Pipes のロール
 */

resource "aws_iam_role" "batch_pipes_role" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-PipesRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": {
      "Effect": "Allow"
      "Action": "sts:AssumeRole"
      "Principal": {
        "Service": "pipes.amazonaws.com"
      }
    }
  })
}

resource "aws_iam_policy" "batch_pipes_source_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-PipesSourcePolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage",
        ],
        "Resource": [
          aws_sqs_queue.pipe_source.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_source_policy" {
  role = aws_iam_role.batch_pipes_role.name
  policy_arn = aws_iam_policy.batch_pipes_source_policy.arn
}

resource "aws_iam_policy" "batch_pipes_target_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-PipesTargetPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "states:StartExecution"
        ],
        "Resource": [
          aws_sfn_state_machine.on_demand_job.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_target_policy" {
  role = aws_iam_role.batch_pipes_role.name
  policy_arn = aws_iam_policy.batch_pipes_target_policy.arn
}


/*******************************
 * StepFunctionsロール
 *******************************/
resource "aws_iam_role" "batch_sfn_role" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-BatchSfnRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "states.amazonaws.com",
        },
        "Action": "sts:AssumeRole",
      }
    ]
  })
}

# Batch実行権限
resource "aws_iam_policy" "batch_job_management_access_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-BatchJobManagementAccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "batch:TerminateJob",
          "batch:SubmitJob"
        ],
        "Resource": [
          "arn:aws:batch:ap-northeast-1:${var.account_id}:job-queue/${var.app_name}-${var.stage}*",
          "arn:aws:batch:ap-northeast-1:${var.account_id}:job/*",
          "arn:aws:batch:ap-northeast-1:${var.account_id}:job-definition/${var.app_name}-${var.stage}-*:*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "batch:DescribeJobs",
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ],
        "Resource": "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_batch_job_management_access_policy" {
  role = aws_iam_role.batch_sfn_role.name
  policy_arn = aws_iam_policy.batch_job_management_access_policy.arn
}

# lambda実行権限
resource "aws_iam_role_policy_attachment" "attach_invoke_lambda_policy" {
  role       = aws_iam_role.batch_sfn_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

# ログ保存用の権限
resource "aws_iam_policy" "cloud_watch_logs_delivery_full_access_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-CloudWatchLogsDeliveryFullAccessPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cloud_watch_logs_delivery_full_access_policy" {
  role = aws_iam_role.batch_sfn_role.name
  policy_arn = aws_iam_policy.cloud_watch_logs_delivery_full_access_policy.arn
}


# デフォルトで作成される権限
resource "aws_iam_policy" "xray_access_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob-XRayAccessPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_xray_access_policy" {
  role = aws_iam_role.batch_sfn_role.name
  policy_arn = aws_iam_policy.xray_access_policy.arn
}

```

# ■ 4. 定義したモジュールをエントリーポイントから参照

`terraform/envs/${ENV_NAME}/main.tf`

```hcl
// ... 略 ...

module "fibonacci_job" { // < 追加 >
  source              = "../../modules/on_demand_job"
  account_id          = local.account_id
  app_name            = local.app_name
  stage               = local.stage
  batch_name          = "fibonacci"
  env                 = {
    "STAGE" : local.stage,
    "SNS_ARN": module.base.sns_topic_arn,
    "DB_NAME": local.stage,
    "DB_SECRET_NAME": "/${local.app_name}/${local.stage}/db",
    "JOB_QUEUE_URL": "dummy"
  }
  batch_job_queue_arn = module.job_base.job_queue_arn
  image_uri           = var.app_image_uri
  image_tag           = "latest"
  command             = [
    "python",
    "/opt/app/job/fibonacci.py",
    "-b",
    "Ref::sqs_message_body",  # SQSに送信されたキューのBody
  ]
  success_handler_arn = module.job_base.success_handler.arn
  error_handler_arn = module.job_base.error_handler.arn
  vcpus               = "1"
  memory              = "2048"
}
```

# ■ 5. デプロイ

```bash
cd ${CONTAINER_PROJECT_ROOT}/terraform/envs/${ENV_NAME}

# 初期化
terraform init

# デプロイ内容確認
terraform plan

# デプロイ
terraform apply -auto-approve
```