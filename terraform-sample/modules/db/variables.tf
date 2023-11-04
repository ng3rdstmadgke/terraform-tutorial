variable "app_name" {}
variable "stage" {}
variable "vpc_id" {}
variable "subnets" {
  type = list
}
variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
variable "ingress_cidr_blocks" {
  type = list(string)
}
variable "instance_num" {
  type = number
}

locals {
  db_port = 3306
}
