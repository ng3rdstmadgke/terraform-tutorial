terraform {
  required_providers {
    # AWS Provider
    #   https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"

  # backends S3
  #   https://developer.hashicorp.com/terraform/language/settings/backends/s3
  backend "s3" {
    # tfstate保存先のs3バケットとキー
    bucket  = "terraform-tutorial-tfstate-store-a5gnpkub"
    region  = "ap-northeast-1"
    key     = "dev/terraform.tfstate"
    encrypt = true
    # tfstateファイルのロック情報を管理するDynamoDBテーブル
    #   https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking
    dynamodb_table = "terraform-tutorial-tfstate-lock"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  # すべてのリソースにデフォルトで設定するタグ
  default_tags {
    tags = {
      PROJECT_NAME = "TERRAFORM_TUTORIAL_D"
    }
  }
}

data "aws_caller_identity" "self" { }
data "aws_region" "current" {}

variable "vpc_id" { type = string }
variable "subnets" { type = list(string) }
variable "alb_subnets" { type = list(string) }
variable "app_image_uri" {type = string}
variable "cicd_artifact_bucket" {type = string}

output "alb_host_name" {
  value = module.alb.app_alb.dns_name
}

output "task_definition" {
  value = "${module.app.ecs_task_family}:${module.app.ecs_task_revision}"
}

locals {
  aws_region = data.aws_region.current.name
  account_id = data.aws_caller_identity.self.account_id
  app_name = "TerraformTutorial"
  app_name_lower = replace(lower(local.app_name), "-", "")
  stage    = "dev"
  vpc_cidr_block = "10.53.0.0/16"
  repository_name= "terraform-tutorial"
  env = {
    "APP_NAME": local.app_name,
    "STAGE": local.stage,
  }
}


module "alb" {
  source      = "../../modules/alb"
  app_name    = local.app_name
  stage       = local.stage
  vpc_id      = var.vpc_id
  alb_subnets = var.alb_subnets
}

module "app" {
  source = "../../modules/app"
  app_name = local.app_name
  stage = local.stage
  account_id = local.account_id
  app_image_uri = var.app_image_uri
  vpc_id = var.vpc_id
  subnets = var.subnets
  ingress_cidr_blocks = [local.vpc_cidr_block]
  app_alb_arn = module.alb.app_alb.arn
  env = local.env
}

module "monitoring" {
  source = "../../modules/monitoring"
  app_name = local.app_name_lower
  stage = local.stage
  ecs_cluster_name = module.app.ecs_cluster_name
  ecs_service_name = module.app.ecs_service_name
  app_tg_1_arn_suffix = module.app.tg_1.arn_suffix
  app_tg_2_arn_suffix = module.app.tg_2.arn_suffix
}

module "cicd" {
  source = "../../modules/cicd"
  app_name = local.app_name
  stage = local.stage
  aws_region = local.aws_region
  account_id = local.account_id
  vpc_id = var.vpc_id
  subnets = var.subnets
  app_image_uri = var.app_image_uri
  ecs_cluster_name = module.app.ecs_cluster_name
  ecs_service_name = module.app.ecs_service_name
  app_tg_1_name = module.app.tg_1.name
  app_tg_2_name = module.app.tg_2.name
  lb_listener_green_arn = module.app.listener_green.arn
  lb_listener_blue_arn = module.app.listener_blue.arn
  cicd_artifact_bucket = var.cicd_artifact_bucket
  repository_name = local.repository_name
  ecs_task_family = module.app.ecs_task_family
}

# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "appspec_yml" {
  filename = "appspec.yml"
  content  = yamlencode({
    version = "0.0"
    Resources = [
      {
        TargetService = {
          Type = "AWS::ECS::Service"
          Properties = {
            PlatformVersion = "1.4.0"
            TaskDefinition = "<TASK_DEFINITION>"
            LoadBalancerInfo = {
              ContainerName = "${module.app.container_name}"
              ContainerPort = module.app.container_port
            }
          }
        }
      }
    ]
  })
}

# https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource
resource "null_resource" "run_script" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "aws ecs describe-task-definition --task-definition ${module.app.ecs_task_family}:${module.app.ecs_task_revision} --query 'taskDefinition' --output json | jq -r '.containerDefinitions[0].image=\"<IMAGE1_NAME>\"' > taskdef.json"
  }
}