# 参考資料

- [それ、どこに出しても恥ずかしくない
Terraformコードになってるか？](https://esa-storage-tokyo.s3-ap-northeast-1.amazonaws.com/uploads/production/attachments/5809/2023/07/07/19598/c89126e6-8d48-4e34-a654-6fd29b63756e.pdf)

# プロジェクト作成

```bash
cd sample
mkdir -p envs/dev modules
touch envs/dev/main.tf
```

```tf
// --- --- --- envs/dev/main.tf --- --- ---
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
```