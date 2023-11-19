variable "app_name" {}
variable "stage" {}
variable "vpc_id" {}
variable "subnets" { type=list(string) }

output "job_queue_arn" {
  value = aws_batch_job_queue.job_queue.arn
}

output "error_handler" {
  value = module.error_handler.lambda_function
}

output "success_handler" {
  value = module.success_handler.lambda_function
}

/**
 * コンピューティング環境のセキュリティグループ
 */
resource "aws_security_group" "compute_environment_sg" {
  name = "${var.app_name}-${var.stage}-BatchComputing-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/**
 * コンピューティング環境
 */

resource "aws_batch_compute_environment" "compute_environment" {
  compute_environment_name = "${var.app_name}-${var.stage}-Batch"

  compute_resources {
    max_vcpus = 32
    security_group_ids = [
      aws_security_group.compute_environment_sg.id
    ]
    subnets = var.subnets
    type = "FARGATE"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type       = "MANAGED"
  depends_on = [
    aws_security_group.compute_environment_sg
  ]
}

/**
 * ジョブキュー
 */
 resource "aws_batch_job_queue" "job_queue" {
  name     = "${var.app_name}-${var.stage}-Batch"
  state    = "ENABLED"
  priority = 1

  compute_environments = [
    aws_batch_compute_environment.compute_environment.arn,
  ]
}

/**
 * Lambda (エラーハンドラー)
 */
# Lambda
module "error_handler" {
  source = "../lambda"
  app_name = var.app_name
  stage = var.stage
  lambda_role_arn = aws_iam_role.lambda_role.arn
  function_name = "BatchErrorHandler"
  handler = "batch_error_handler.handler"
  vpc_id = var.vpc_id
  subnets = var.subnets
  env = {}
}

/**
 * Lambda (サクセスハンドラー)
 */
# Lambda
module "success_handler" {
  source = "../lambda"
  app_name = var.app_name
  stage = var.stage
  lambda_role_arn = aws_iam_role.lambda_role.arn
  function_name = "BatchSuccessHandler"
  handler = "batch_success_handler.handler"
  vpc_id = var.vpc_id
  subnets = var.subnets
  env = {}
}