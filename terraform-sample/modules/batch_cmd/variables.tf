variable "account_id" {}
variable "app_name" {}
variable "stage" {}
variable "batch_name" {}
variable "env" { type = map }
variable "batch_job_queue_arn" {}
variable "image_uri" {}
variable "image_tag" {}
variable "command" { type = list(string) }
variable "success_handler_arn" {}
variable "error_handler_arn" {}
variable "vcpus" {
  type=string
  default="1"
}

variable "memory" {
  type=string
  default="2048"
}