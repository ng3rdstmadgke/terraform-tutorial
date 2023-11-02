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

output "alb_host_name" {
  value = module.alb.app_alb.dns_name
}

locals {
  aws_region = data.aws_region.current.name
  account_id = data.aws_caller_identity.self.account_id
  app_name = "TerraformTutorial"
  app_name_lower = replace(lower(local.app_name), "-", "")
  stage    = "dev"
  vpc_cidr_block = "10.53.0.0/16"
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
  app_image = var.app_image_uri
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