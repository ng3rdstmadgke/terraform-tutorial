/**
 * Batchコンピューティング環境のサービスロール
 */
resource "aws_iam_role" "aws_batch_service_role" {
  name = "${var.app_name}-${var.stage}-BatchComputingServiceRole"
  assume_role_policy = data.aws_iam_policy_document.assume_aws_batch_service_role_policy.json
}

data "aws_iam_policy_document" "assume_aws_batch_service_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

/**
 * Lambda実行ロール
 */

resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-${var.stage}-BatchLambdaRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com",
        },
        "Action": "sts:AssumeRole",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_vpc_access_execution_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "lambda_role_policy" {
  name = "${var.app_name}-${var.stage}-BatchLambdaRolePolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource": [
          "*"
        ],
      },
      {
        "Effect": "Allow",
        "Action": [
          "sns:Publish"
        ],
        "Resource": [
          "*"
        ],
      },
      {
        "Effect": "Allow",
        "Action": [
          "sqs:SendMessage"
        ],
        "Resource": [
          "*"
        ],
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_role_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_role_policy.arn
}
