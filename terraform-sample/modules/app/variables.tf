variable "app_name" {}
variable "stage" {}
variable "account_id" {}
variable "app_image" {}
variable "vpc_id" {}
variable "subnets" { type=list(string) }
variable "ingress_cidr_blocks" {
  type = list(string)
}
variable "app_alb_arn" {}
variable "env" {type=map}

variable "certificate_arn" {
  type = string
  default = ""
  description = "SSL証明書のARN。空文字の場合はHTTPのリスナーを作成する"
}

locals {
  use_https_listener = length(var.certificate_arn) > 0  ? "1" : "0"
  use_http_listener  = length(var.certificate_arn) <= 0 ? "1" : "0"
}
