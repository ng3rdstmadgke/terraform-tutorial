Chapter3 バッチコンピューティング環境
---
[READMEに戻る](../README.md)

# ■ 1. 作るもの

この章ではAWS Batchのコンピューティング環境や成功・エラー通知用のLambdaなど、ジョブ実行の仕組みで共通して利用するリソースを作成します。

<img src="img/03/drawio/architecture.drawio.png" width="900px">

# ■ 2. lambdaモジュールの作成

VPC上で動作するlambda関数をデプロイするためのモジュールを作成します。


## 1. ファイルの作成

`lambda` モジュールを定義します。

```bash
ENV_NAME="your_name"
mkdir -p ${CONTAINER_PROJECT_ROOT}/terraform/modules/lambda
touch ${CONTAINER_PROJECT_ROOT}/terraform/modules/lambda/{main.tf,variables.tf,outputs.tf,iam.tf}
```

## 2. 入力値・出力値の定義

`terraform/modules/lambda/variables.tf`

```hcl
variable "app_name" { }
variable "stage" { }

// lambdaにアタッチするロール
variable "lambda_role_arn" { }

// lambdaの名前
variable "function_name" { }

// lambdaハンドラ
variable "handler" {}

// lambdaが動作するvpc
variable "vpc_id" { }

// lambdaが動作するサブネット
variable "subnets" {
  type=list(string)
}

// lambdaに設定する環境変数
variable "env" { type = map }

// lambdaのメモリサイズ
variable "memory_size" {
  default = 128
  type    = number
}

// lambdaのストレージサイズ
variable "ephemeral_storage_size" {
  default = 512
  type    = number
}
```

`terraform/modules/lambda/variables.tf`

```hcl
output "lambda_function" {
  value = aws_lambda_function.lambda_function
}
```

## 3. リソース定義

lambda関数のデプロイにはzip圧縮されたレイヤーとソースコードが必要ですが、lambdaモジュールではそれらの生成も行います。  
`null_resource.package_lambda_resource` リソースでMakefileを実行し、ライブラリのインストールとソースコードのコピーを行い、`archive_file.*` でzip圧縮を行います。

※ Makefile は `app/Makefile` にあります


`terraform/modules/lambda/main.tf`

```hcl
// LambdaのレイヤーとソースコードをパッケージングするMakefileを実行
resource "null_resource" "package_lambda_resource" {
  // https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource
  triggers = {
    always_run = timestamp()
  }
  // local-exec: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
  provisioner "local-exec" {
    command = "make -C ../../../app package FUNCTION_NAME=${var.function_name}"
  }
}

// Makefileで作成したレイヤーをzipに圧縮
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "../../../.lambda-build/${var.function_name}/layer"
  output_path = "../../../.lambda-build/${var.function_name}/dist/layer.zip"
  depends_on = [ 
    null_resource.package_lambda_resource
   ]
}

// Makefileで作成したソースコードをzipに圧縮
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "../../../.lambda-build/${var.function_name}/src"
  output_path = "../../../.lambda-build/${var.function_name}/dist/src.zip"
  depends_on = [ 
    null_resource.package_lambda_resource
  ]
}

// Layer
resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name = "${var.app_name}-${var.stage}-${var.function_name}-layer"
  filename   = "${data.archive_file.layer_zip.output_path}"
  source_code_hash = "${data.archive_file.layer_zip.output_base64sha256}"
}

// セキュリティグループ
resource "aws_security_group" "lambda_sg" {
  name = "${var.app_name}-${var.stage}-${var.function_name}-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 }
 tags = {
   Name = "${var.app_name}-${var.stage}-${var.function_name}-sg"
 }
}

// Function
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.app_name}-${var.stage}-${var.function_name}"
  handler = "${var.handler}"
  filename = "${data.archive_file.function_zip.output_path}"
  // 利用可能なランタイム: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
  runtime = "python3.11"
  role = "${var.lambda_role_arn}"
  source_code_hash = "${data.archive_file.function_zip.output_base64sha256}"
  layers = ["${aws_lambda_layer_version.lambda_layer.arn}"]
  timeout = 900
  memory_size = var.memory_size
  vpc_config {
    subnet_ids = var.subnets
    security_group_ids = [
      aws_security_group.lambda_sg.id
    ]
  }
  environment {
    variables = var.env
  }
  ephemeral_storage {
    size = var.ephemeral_storage_size
  }
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_event_invoke_config
resource "aws_lambda_function_event_invoke_config" "lambda_function_config" {
  function_name                = aws_lambda_function.lambda_function.function_name
  maximum_event_age_in_seconds = 3600
  maximum_retry_attempts       = 0
}
```

# ■ 2. job_baseモジュールの作成

job_baseモジュールでは、AWS Batchのコンピューティング環境の作成と、lambdaモジュールを利用したジョブ共通で必要なlambda関数の作成を行います。  


## 1. ファイルの作成

`job_base` モジュールを定義します。

```bash
ENV_NAME="your_name"
mkdir -p ${CONTAINER_PROJECT_ROOT}/terraform/modules/job_base
touch ${CONTAINER_PROJECT_ROOT}/terraform/modules/job_base/{main.tf,variables.tf,outputs.tf,iam.tf}
```

## 2. 入力値・出力値の定義

`terraform/modules/job_base/variables.tf`

```hcl
variable "app_name" {}
variable "stage" {}

// Batch が動作するVPC
variable "vpc_id" {}

// Batch が動作するサブネット
variable "subnets" { type=list(string) }

// Batch に設定する環境変数
variable "env" { type = map }
```

`terraform/modules/job_base/variables.tf`

```hcl
output "job_queue_arn" {
  value = aws_batch_job_queue.job_queue.arn
}

output "error_handler" {
  value = module.error_handler.lambda_function
}

output "success_handler" {
  value = module.success_handler.lambda_function
}

```

## 3. リソース定義


`terraform/modules/job_base/main.tf`

```hcl
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
    aws_security_group.compute_environment_sg,
    aws_iam_role_policy_attachment.aws_batch_service_role
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
  env = var.env

  depends_on = [
    aws_iam_role.lambda_role
  ]
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
  env = var.env

  depends_on = [
    aws_iam_role.lambda_role
  ]
}
```

`terraform/modules/job_base/iam.tf`

```hcl
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
```


# ■ 4. 定義したモジュールをエントリーポイントから参照



`terraform/envs/${ENV_NAME}/main.tf`

```hcl
// ... 略 ...

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

module "job_base" { // < 追加 >
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
```

# ■ 4. デプロイ

```bash
cd ${CONTAINER_PROJECT_ROOT}/terraform/envs/${ENV_NAME}

# 初期化
terraform init

# デプロイ内容確認
terraform plan

# デプロイ
terraform apply -auto-approve
```