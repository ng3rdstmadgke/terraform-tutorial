variable "app_name" {}
variable "stage" {}
variable "account_id" {}

// ECSタスクのコンテナイメージのURI
variable "app_image_uri" {}

// ECSのセキュリティグループ・ALBのターゲットグループを作成するVPC
variable "vpc_id" {}

// ECSタスクを起動するサブネット
variable "subnets" { type = list(string) }

// ECSのセキュリティグループで許可するCIDRブロック
variable "ingress_cidr_blocks" {
  type = list(string)
}

// ALBのARN
variable "app_alb_arn" {}

// コンテナの環境変数
variable "env" { type = map(any) }

variable "sns_topic_arn" {}

variable "job_queue_arn" {}

// HTTPSでアクセスする場合のSSL証明書のARN
variable "certificate_arn" {
  type        = string
  default     = ""
  description = "SSL証明書のARN。空文字の場合はHTTPのリスナーを作成する"
}

locals {
  // certificate_arnが指定されていたら "1"
  use_https_listener = length(var.certificate_arn) > 0 ? "1" : "0"
  // certificate_arnが指定されていたら "0"
  use_http_listener  = length(var.certificate_arn) <= 0 ? "1" : "0"
  container_name     = "app"  // コンテナ名
  container_port     = 80  // コンテナのポート番号
}
