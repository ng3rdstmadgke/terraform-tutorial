variable "app_name" {}
variable "stage" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "app_tg_1_arn_suffix" {}
variable "app_tg_2_arn_suffix" {}
variable "max_capacity" {
  type=number
  default=20
}
variable "avg_request_count_per_target" {
  type=number
  default=300
}
