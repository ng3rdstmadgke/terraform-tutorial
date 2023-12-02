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