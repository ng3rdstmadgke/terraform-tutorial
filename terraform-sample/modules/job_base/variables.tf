variable "app_name" {}
variable "stage" {}

// Batch が動作するVPC
variable "vpc_id" {}

// Batch が動作するサブネット
variable "subnets" { type=list(string) }

// Batch に設定する環境変数
variable "env" { type = map }