variable "app_name" { }
variable "stage" { }
variable "lambda_role_arn" { }
variable "function_name" { }
variable "handler" {}
variable "vpc_id" { }
variable "subnets" {
  type=list(string)
}
variable "env" { type = map }

variable "memory_size" {
  default = 128
  type    = number
}

variable "ephemeral_storage_size" {
  default = 512
  type    = number
}