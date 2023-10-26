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
    bucket  = "tfstate-store-a5gnpkub"
    region  = "ap-northeast-1"
    key     = "terraform-tutorial/dev/terraform.tfstate"
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

variable "vpc_id" { type = string }
variable "subnets" { type = list(string) }
variable "alb_subnets" { type = list(string) }
variable "app_image_uri" {type = string}
variable "app_image_tag" {type = string}

locals {
  aws_region = data.aws_region.current.name
  account_id = data.aws_caller_identity.self.account_id
  app_name = "terraform-tutorial"
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
  app_alb_arn = module.app_alb.alb.arn
  env = local.env
}