variable "app_name" {}
variable "stage" {}
variable "vpc_id" {}
variable "alb_subnets" { type = list(string) }
variable "ingress_rules_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
