/**
 * ALB用セキュリティグループ
 * aws_security_group: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
 */
resource "aws_security_group" "app_alb_sg" {
  name   = "${var.app_name}-${var.stage}-app-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_rules_cidr_blocks
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.ingress_rules_cidr_blocks
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ingress_rules_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-${var.stage}-app-alb-sg"
  }
}

/**
 * ALB
 * aws_alb: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
 */
resource "aws_lb" "app_alb" {
  name               = "${var.app_name}-${var.stage}-app-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb_sg.id]
  subnets            = var.alb_subnets
  ip_address_type    = "ipv4"
  idle_timeout       = 60
  internal           = false

  lifecycle {
    # 変更を適用しない
    # https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#ignore_changes
    ignore_changes = all
    # 強制的なリソースの再作成が起こらないようにする
    # https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#prevent_destroy
    #prevent_destroy = true
  }
}
