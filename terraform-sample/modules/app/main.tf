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


/**
 * Output
 */
output "ecs_cluster_name" {
  value = aws_ecs_cluster.app_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecs_task_family" {
  value = aws_ecs_task_definition.app_task_definition.family
}

output "ecs_task_revision" {
  value = aws_ecs_task_definition.app_task_definition.revision
}


output "esc_task_definition_arn" {
  value = aws_ecs_task_definition.app_task_definition.arn
}

output "tg_1" {
  value = aws_lb_target_group.app_tg_1
}

output "tg_2" {
  value = aws_lb_target_group.app_tg_2
}

output "listener_green" {
  # countを利用したリソースはlistになるので、インデックスを指定する
  value = length(var.certificate_arn) > 0  ? aws_lb_listener.app_listener_green_https.0 : aws_lb_listener.app_listener_green_http.0
}

output "listener_blue" {
  value = aws_lb_listener.app_listener_blue
}

/**
 * ALBターゲットグループ
 */
resource "aws_lb_target_group" "app_tg_1" {
  name        = "${var.app_name}-${var.stage}-app-tg-1"
  port        = "80"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    path                = "/healthcheck"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${var.app_name}-${var.stage}-app-tg-1"
  }
}

resource "aws_lb_target_group" "app_tg_2" {
  name        = "${var.app_name}-${var.stage}-app-tg-2"
  port        = "80"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    path                = "/healthcheck"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${var.app_name}-${var.stage}-app-tg-2"
  }
}

/**
 * ALBのリスナー
 *
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
 */

/**
 * HTTPS を利用する場合のリスナー
 */
# HTTPS:443 (Green用リスナー)
resource "aws_lb_listener" "app_listener_green_https" {
  # use_https_listener = "1" のときのみ作成
  # Terraformでcountをifのように使う: https://qiita.com/mia_0032/items/978449a06699ed1abe15
  count = local.use_https_listener
  load_balancer_arn = var.app_alb_arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "forward"
    forward {
     target_group {
       arn    = aws_lb_target_group.app_tg_1.arn
       weight = 1
     }
    }
  }
  lifecycle {
    ignore_changes = [
      certificate_arn,
      default_action
    ]
  }
}

# HTTP:80 (HTTPS:443 にリダイレクト)
resource "aws_lb_listener" "app_listener_redirect" {
  # use_https_listener = "1" のときのみ作成
  count = local.use_https_listener
  load_balancer_arn = var.app_alb_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  lifecycle {
    ignore_changes = [
      default_action
    ]
  }
}

/**
 * HTTP を利用する場合のリスナー
 */
resource "aws_lb_listener" "app_listener_green_http" {
  # use_http_listener = "1" のときのみ作成
  count = local.use_http_listener
  load_balancer_arn = var.app_alb_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
     target_group {
       arn    = aws_lb_target_group.app_tg_1.arn
       weight = 1
     }
    }
  }
  lifecycle {
    ignore_changes = [
      default_action
    ]
  }
}


/**
 * 共通のリスナー
 */
# HTTP:8080 (Blue用リスナー)
resource "aws_lb_listener" "app_listener_blue" {
  load_balancer_arn = var.app_alb_arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.app_tg_2.arn
        weight = 1
      }
    }
  }
  lifecycle {
    ignore_changes = [
      default_action
    ]
  }
}


/**
 * ECSクラスター
 */
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-${var.stage}-app"

  setting {
    # CloudWatch Container Insights を有効化
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "app_cluster_capacity_providers" {
  cluster_name = aws_ecs_cluster.app_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1  # 指定されたキャパシティプロバイダ上で実行するタスクの最小数
    weight            = 1  # 指定されたキャパシティプロバイダを使用すべきタスク総数の割合
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 2
    capacity_provider = "FARGATE_SPOT"
  }
}

/**
 * ロググループ
 */
resource "aws_cloudwatch_log_group" "ecs_task_app_log_group" {
  name = "${var.app_name}/${var.stage}/app/ecs-task"
  retention_in_days = 365
}

/**
 * タスク定義
 */

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "app_task_definition" {
  family = "${var.app_name}-${var.stage}-app"

  # タスクが必要とする起動タイプ
  requires_compatibilities = ["FARGATE"]

  # タスクサイズ:
  #   タスクが利用する CPU および メモリの合計量。FARGATEの場合は必須。
  #   cpuとmemoryの値にはペアがあるので注意
  #   - https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
  cpu = 2048  # 2vCPU
  memory = 4096  # 4GB

  # ネットワークモード:
  #   FARGATEではawsvpcのみ
  #   - https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definition_parameters.html#network_mode
  #   - https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/bestpracticesguide/networking-networkmode.html
  network_mode             = "awsvpc"

  # ランタイムプラットフォーム:
  #   コンテナのホストOSの情報
  #   - https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definition_parameters.html#runtime-platform
  runtime_platform { #
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # タスクに割り当てられるストレージ容量 (GiB)
  ephemeral_storage {
    size_in_gib = 32
  }

  # タスク実行ロール
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  # タスクロール
  task_role_arn = aws_iam_role.ecs_task_role.arn

  # コンテナ定義:
  #   - https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.app_image
      cpu       = 1024  # コンテナが利用するCPU (1vCPU)
      memory    = 1024  # コンテナが利用するメモリ (1GB)
      essential = true  # essential=Trueのコンテナが停止した場合、タスク全体が停止する
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        for k, v in var.env : {
          name = k
          value = v
        }
      ]
      command = ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

      # 終了シグナル発進時、この秒数を超えてコンテナが終了しない場合は強制終了させる
      stopTimeout = 30

      # ログの設定
      #  - https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.ecs_task_app_log_group.name
          awslogs-region = "ap-northeast-1"
          awslogs-stream-prefix = "app"
        }
      }

      # dockerのヘルスチェック機能: https://docs.docker.jp/engine/reference/run.html#run-healthcheck
      # 書き方: https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-healthcheck.html
      HealthCheck = {
        command = ["CMD-SHELL", "curl -H 'User-Agent: Docker-HealthChecker' -f 'http://localhost/healthcheck' || exit 1"]
        interval = 15
        timeout = 5
        retries = 3
        startPeriod = 30
      }

      # コンテナに適用されるLinux特有のオプション
      #   - https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LinuxParameters.html
      #linuxParameters = {
      #  init_process_enabled = true
      #}
    }
  ])
}

/**
 * ECSサービス用セキュリティグループ
 */
resource "aws_security_group" "esc_service_sg" {
  name = "${var.app_name}-${var.stage}-app-EcsService-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  tags = {
     Name = "${var.app_name}-${var.stage}-app-EcsService-sg"
  }
}

/**
 * サービス
 */

# aws_ecs_service: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
resource "aws_ecs_service" "app_service" {
  name = "${var.app_name}-${var.stage}-app"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task_definition.arn
  desired_count   = 1
  platform_version = "1.4.0"
  launch_type = "FARGATE"
  # タスクが落ちた時のスケジューリング方式(FARGATEで指定できるのはREPLICAのみ)
  #   - https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/ecs_services.html#service_scheduler_replica
  scheduling_strategy = "REPLICA"  # クラスター全体で必要数のタスクを維持する

  # 新しくタスクが立ち上がった際、この秒数だけヘルスチェックの失敗を無視する
  health_check_grace_period_seconds = 300

  network_configuration {
    subnets = var.subnets
    security_groups = [ aws_security_group.esc_service_sg.id ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg_1.arn
    container_name   = "app"
    container_port   = 80
  }

  deployment_controller {
    # ECS: ローリングアップデート
    # CODE_DEPLOY: Blue/Greenデプロイ
    type = "CODE_DEPLOY"
  }

  # デプロイ中にサービス内で実行され、健全な状態を維持しなければならない実行タスク数の下限
  deployment_minimum_healthy_percent = 100

  # デプロイ中にサービス内で実行可能な実行タスク数の上限
  deployment_maximum_percent = 200

  # デバッグ用の設定
  # https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/userguide/ecs-exec.html
  enable_execute_command = true

  lifecycle {
    ignore_changes = [
      load_balancer,
      desired_count,
      task_definition,
    ]
  }
  depends_on = [
    aws_lb_listener.app_listener_blue,
    aws_lb_listener.app_listener_green_https,
    aws_lb_listener.app_listener_green_http,
  ]
}