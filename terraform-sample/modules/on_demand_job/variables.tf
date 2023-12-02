variable "account_id" {}
variable "app_name" {}
variable "stage" {}

// Batchの名前
variable "batch_name" {}

// Batch に設定する環境変数
variable "env" { type = map }

// Batchのジョブキュー
variable "batch_job_queue_arn" {}

// Batchで利用するイメージのURI
variable "image_uri" {}

// Batchで利用するイメージのタグ
variable "image_tag" {}

// Batchで実行するコマンド
variable "command" { type = list(string) }

// Stepfunctionsで成功処理を行うLambda関数
variable "success_handler_arn" {}

// Stepfunctionsでエラー処理を行うLambda関数
variable "error_handler_arn" {}

// Batchで利用するvCPU数
variable "vcpus" {
  type=string
  default="1"
}

// Batchで利用するメモリサイズ
variable "memory" {
  type=string
  default="2048"
}

locals {
  job_name = "${var.app_name}-${var.stage}-${var.batch_name}-OnDemandJob"
}