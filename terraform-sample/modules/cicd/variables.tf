variable "app_name" {}
variable "stage" {}
variable "aws_region" {}
variable "account_id" {}
variable "vpc_id" {}
variable "subnets" { type = list(string) }
variable "app_image_uri" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "app_tg_1_name" {}
variable "app_tg_2_name" {}
variable "lb_listener_green_arn" {}
variable "lb_listener_blue_arn" {}
variable "cicd_artifact_bucket" {}
variable "repository_name" {}
variable "ecs_task_family" {}