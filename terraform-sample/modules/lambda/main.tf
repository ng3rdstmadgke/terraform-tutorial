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