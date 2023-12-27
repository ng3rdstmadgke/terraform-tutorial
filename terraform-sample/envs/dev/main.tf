terraform {
  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  // terraformのバージョン指定
  required_version = ">= 1.2.0"

  // tfstateファイルをs3で管理する: https://developer.hashicorp.com/terraform/language/settings/backends/s3
  backend "s3" {
    // tfstate保存先のs3バケットとキー
    bucket  = "terraform-tutorial-tfstate-store-a5gnpkub"
    region  = "ap-northeast-1"
    key     = "dev/terraform.tfstate"
    encrypt = true
    // tfstateファイルのロック情報をDynamoDBで管理する: https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking
    dynamodb_table = "terraform-tutorial-tfstate-lock"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  // すべてのリソースにデフォルトで設定するタグ
  default_tags {
    tags = {
      PROJECT_NAME = "TERRAFORM_TUTORIAL_D"
    }
  }
}

// Data Source: aws_caller_identity: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
// Terraformが認可されているアカウントの情報を取得するデータソース
data "aws_caller_identity" "self" {}

// Data Source: aws_region: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region
// 現在のリージョンを取得するデータソース
data "aws_region" "current" {}

// ローカル変数を定義
locals {
  aws_region      = data.aws_region.current.name
  account_id      = data.aws_caller_identity.self.account_id
  app_name        = replace(lower("terraformtutorial"), "-", "")
  stage           = "dev"
  vpc_cidr_block  = "10.53.0.0/16"
  repository_name = "terraform-tutorial"
}

// 変数定義
variable "vpc_id" { type = string }
variable "subnets" { type = list(string) }
variable "db_user" { type = string }
variable "db_password" { type = string }
variable "app_image_uri" { type = string }
variable "alb_subnets" { type = list(string) }
variable "cicd_artifact_bucket" { type = string }

// 出力
output db_secrets_manager_arn {
  value = module.db.db_secrets_manager_arn
}

output "alb_host_name" {
  value = module.alb.app_alb.dns_name
}

output "task_definition" {
  value = "${module.app.ecs_task_family}:${module.app.ecs_task_revision}"
}

module "base" {
  source = "../../modules/base"
  app_name    = local.app_name
  stage       = local.stage
}

module "db" {
  source              = "../../modules/db"
  app_name            = local.app_name
  stage               = local.stage
  vpc_id              = var.vpc_id
  subnets             = var.subnets
  db_name             = local.stage
  db_user             = var.db_user
  db_password         = var.db_password
  ingress_cidr_blocks = [local.vpc_cidr_block]
  instance_num        = 1
}

module "job_base" {
  source              = "../../modules/job_base"
  app_name            = local.app_name
  stage               = local.stage
  vpc_id              = var.vpc_id
  subnets             = var.subnets
  env                 = {
    "STAGE" : local.stage,
    "SNS_ARN": module.base.sns_topic_arn,
    "DB_NAME": local.stage,
    "DB_SECRET_NAME": "/${local.app_name}/${local.stage}/db",
    "JOB_QUEUE_URL": "dummy"
  }
}

module "fibonacci_job" {
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

module "crawler_job" {
  source              = "../../modules/scheduled_job"
  account_id          = local.account_id
  app_name            = local.app_name
  stage               = local.stage
  batch_name          = "crawler"
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
    "/opt/app/job/crawler.py",
  ]
  success_handler_arn = module.job_base.success_handler.arn
  error_handler_arn = module.job_base.error_handler.arn
  vcpus               = "1"
  memory              = "2048"
  # https://docs.aws.amazon.com/ja_jp/scheduler/latest/UserGuide/schedule-types.html
  schedule_expression = "rate(5 minutes)"  # 5分おき
}

module "alb" {
  source      = "../../modules/alb"
  app_name    = local.app_name
  stage       = local.stage
  vpc_id      = var.vpc_id
  alb_subnets = var.alb_subnets
}

module "app" {
  source              = "../../modules/app"
  app_name            = local.app_name
  stage               = local.stage
  account_id          = local.account_id
  app_image_uri       = var.app_image_uri
  vpc_id              = var.vpc_id
  subnets             = var.subnets
  ingress_cidr_blocks = [local.vpc_cidr_block]
  app_alb_arn         = module.alb.app_alb.arn
  sns_topic_arn       = module.base.sns_topic_arn
  job_queue_arn       = module.fibonacci_job.queue_arn
  env                 = {
    "STAGE" : local.stage,
    "SNS_ARN": module.base.sns_topic_arn,
    "DB_NAME": local.stage,
    "DB_SECRET_NAME": "/${local.app_name}/${local.stage}/db",
    "JOB_QUEUE_URL": module.fibonacci_job.queue_url,
  }
}

// 環境変数ファイルを作成
resource "local_file" "env_file" {
  // https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
  filename = "../../../env/${local.stage}.env"
  content  = <<EOF
STAGE=${local.stage}
SNS_ARN=${module.base.sns_topic_arn}
DB_NAME=${local.stage}
DB_SECRET_NAME=/${local.app_name}/${local.stage}/db
JOB_QUEUE_URL=${module.fibonacci_job.queue_url}

EOF
}

module "monitoring" {
  source              = "../../modules/monitoring"
  app_name            = local.app_name
  stage               = local.stage
  ecs_cluster_name    = module.app.ecs_cluster_name
  ecs_service_name    = module.app.ecs_service_name
  app_tg_1_arn_suffix = module.app.tg_1.arn_suffix
  app_tg_2_arn_suffix = module.app.tg_2.arn_suffix
}

module "cicd" {
  source                = "../../modules/cicd"
  app_name              = local.app_name
  stage                 = local.stage
  aws_region            = local.aws_region
  account_id            = local.account_id
  vpc_id                = var.vpc_id
  subnets               = var.subnets
  app_image_uri         = var.app_image_uri
  ecs_cluster_name      = module.app.ecs_cluster_name
  ecs_service_name      = module.app.ecs_service_name
  app_tg_1_name         = module.app.tg_1.name
  app_tg_2_name         = module.app.tg_2.name
  lb_listener_green_arn = module.app.listener_green.arn
  lb_listener_blue_arn  = module.app.listener_blue.arn
  cicd_artifact_bucket  = var.cicd_artifact_bucket
  repository_name       = local.repository_name
  ecs_task_family       = module.app.ecs_task_family
}

resource "null_resource" "make_dir" {
  // https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource
  triggers = {
    always_run = timestamp()
    stage = local.stage
  }

  // terraform apply で実行される
  // local-exec: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
  provisioner "local-exec" {
    command = "mkdir -p ../../../tfexports/${self.triggers.stage}"
  }

  // terraform destroy で実行される
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ../../../tfexports/${self.triggers.stage}"
  }
}

// appspec.ymlを作成
resource "local_file" "appspec_yml" {
  // https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
  filename = "../../../tfexports/${local.stage}/appspec.yaml"
  content  = <<EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "${module.app.container_name}"
          ContainerPort: ${module.app.container_port}
        PlatformVersion: "1.4.0"
EOF

  depends_on = [null_resource.make_dir]
}

// taskdef.jsonを作成
resource "null_resource" "run_script" {
  // https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource
  triggers = {
    always_run = timestamp()
  }

  // terraform apply で実行される
  provisioner "local-exec" {
    command = <<EOF
aws ecs describe-task-definition \
  --task-definition ${module.app.ecs_task_family}:${module.app.ecs_task_revision} \
  --query 'taskDefinition' \
  --output json |
jq -r '.containerDefinitions[0].image="<IMAGE1_NAME>"' \
> ../../../tfexports/${local.stage}/taskdef.json
EOF
  }
  depends_on = [null_resource.make_dir]
}
