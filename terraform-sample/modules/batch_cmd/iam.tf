/*******************************
 * ECSタスク実行ロール
 *******************************/
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-EcsTaskExecutionRole"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-EcsTaskRole"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-EcsTaskRolePolicy"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-PipesRole"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-PipesSourcePolicy"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-PipesTargetPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "states:StartExecution"
        ],
        "Resource": [
          aws_sfn_state_machine.pipe_target.arn
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-BatchSfnRole"
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
resource "aws_iam_policy" "batch_job_management_full_access_policy" {
  name = "${var.app_name}-${var.stage}-BatchJobManagementFullAccessPolicy"
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

resource "aws_iam_role_policy_attachment" "attach_batch_job_management_full_access_policy" {
  role = aws_iam_role.batch_sfn_role.name
  policy_arn = aws_iam_policy.batch_job_management_full_access_policy.arn
}

# lambda実行権限
resource "aws_iam_role_policy_attachment" "attach_invoke_lambda_policy" {
  role       = aws_iam_role.batch_sfn_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

# ログ保存用の権限
resource "aws_iam_policy" "cloud_watch_logs_delivery_full_access_policy" {
  name = "${var.app_name}-${var.stage}-${var.batch_name}-CloudWatchLogsDeliveryFullAccessPolicy"
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
  name = "${var.app_name}-${var.stage}-${var.batch_name}-XRayAccessPolicy"
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
