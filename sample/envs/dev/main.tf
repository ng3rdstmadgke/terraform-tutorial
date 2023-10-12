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
    bucket = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
    region = "ap-northeast-1"
    key = "terraform-tutorial/dev/terraform.tfstate"
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
      PROJECT_NAME = "TERRAFORM_TUTORIAL"
    }
  }
}