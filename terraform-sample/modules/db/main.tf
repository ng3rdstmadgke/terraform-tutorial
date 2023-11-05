#
# DBクラスタ (Aurora Serverless v2)
#
resource "aws_rds_cluster_parameter_group" "aurora_serverless_mysql80" {
  name   = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80-cluster-parameter-group"
  family = "aurora-mysql8.0"

  parameter {
    name         = "time_zone"
    value        = "Asia/Tokyo"
    apply_method = "immediate"
  }
  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_filesystem"
    value = "binary"
  }
  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_connection"
    value = "utf8mb4_bin"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_bin"
  }
}

resource "aws_db_subnet_group" "aurora_serverless_mysql80" {
  name       = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80-sg"
  subnet_ids = var.subnets
}

resource "aws_security_group" "aurora_serverless_mysql80" {
  name   = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }
  tags = {
    "Name" = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80"
  }
}

// aws_rds_cluster: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
// Requirements for Aurora Serverless V2 : https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.requirements.html
resource "aws_rds_cluster" "aurora_serverless_mysql80" {
  cluster_identifier = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80-cluster"

  engine = "aurora-mysql"
  // 利用可能なバージョンの一覧
  /*
    aws rds describe-orderable-db-instance-options \
      --engine aurora-mysql \
      --db-instance-class db.serverless \
      --region ap-northeast-1 \
      --query 'OrderableDBInstanceOptions[].[EngineVersion]' \
      --output text
  */
  engine_version = "8.0.mysql_aurora.3.05.0"

  database_name   = var.db_name
  master_username = var.db_user
  master_password = var.db_password
  port            = local.db_port

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_serverless_mysql80.name

  backup_retention_period = 7

  // aws_rds_cluster_instance.db_subnet_group_nameと一致している必要がある
  db_subnet_group_name   = aws_db_subnet_group.aurora_serverless_mysql80.name
  vpc_security_group_ids = [aws_security_group.aurora_serverless_mysql80.id]

  // スケールアップ/ダウン時の最小ACU, 最大ACUを定義
  serverlessv2_scaling_configuration {
    min_capacity = 0.5 // 0.5 ~
    max_capacity = 1.0 // ~ 128
  }

  // 削除時にスナップショットを作成しな時
  skip_final_snapshot = true
  // スナップショットを取得したい場合は final_snapshot_identifier が必要
  #final_snapshot_identifier = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80-cluster-final-snapshot-${timestamp()}"

  lifecycle {
    ignore_changes = [
      master_password // パスワードが変更されていても無視する
    ]
    #prevent_destroy = true
  }
}

#
# DBインスタンス (Aurora Serverless v2)
#

// aws_rds_cluster_instance: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance
resource "aws_rds_cluster_instance" "aurora_serverless_mysql80" {
  // DBインスタンスをいくつ作るか
  // 例)
  //   3 なら wrインスタンス = 1, roインスタンス = 2
  //   5 なら wrインスタンス = 1, roインスタンス = 4
  count              = var.instance_num
  cluster_identifier = aws_rds_cluster.aurora_serverless_mysql80.id
  // Aurora Serverless V2を利用する場合は db.serverless 固定
  instance_class = "db.serverless"
  engine         = aws_rds_cluster.aurora_serverless_mysql80.engine
  engine_version = aws_rds_cluster.aurora_serverless_mysql80.engine_version

  // インスタンスで上書き
  db_parameter_group_name = aws_db_parameter_group.aurora_serverless_mysql80.name
  // クラスタと同じサブネットグループを利用
  db_subnet_group_name = aws_rds_cluster.aurora_serverless_mysql80.db_subnet_group_name
  // パブリックアクセス不可
  publicly_accessible = false
}

resource "aws_db_parameter_group" "aurora_serverless_mysql80" {
  // インスタンスごとに設定したいパラメータグループがある時はこちら
  name   = "${var.app_name}-${var.stage}-aurora-serverless-v2-mysql80-instance-parameter-group"
  family = "aurora-mysql8.0"
}

#
# DBのログイン情報を保持する SecretsManager
#
resource "aws_secretsmanager_secret" "aurora_serverless_mysql80" {
  name                           = "/${var.app_name}/${var.stage}/db"
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "aurora_serverless_mysql80" {
  secret_id = aws_secretsmanager_secret.aurora_serverless_mysql80.id
  secret_string = jsonencode({
    db_user     = var.db_user
    db_password = var.db_password
    db_host     = aws_rds_cluster.aurora_serverless_mysql80.endpoint
    db_port     = aws_rds_cluster.aurora_serverless_mysql80.port
  })
}



#
# 普通のRDS
#
/*
resource "aws_security_group" "app_db_sg" {
  name = "${var.app_name}-${var.stage}-db"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = local.db_port
    to_port = local.db_port
    protocol = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }
  tags = {
    "Name" = "${var.app_name}-${var.stage}-db"
  }
}

resource "aws_db_parameter_group" "app_db_pg" {
  name = "${var.app_name}-${var.stage}-db"
  family = "mysql8.0"
  parameter {
    name = "character_set_client"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_connection"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_database"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_filesystem"
    value = "binary"
  }
  parameter {
    name = "character_set_results"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name = "collation_connection"
    value = "utf8mb4_bin"
  }
  parameter {
    name = "collation_server"
    value = "utf8mb4_bin"
  }
}

resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "${var.app_name}-${var.stage}-db"
  subnet_ids = var.subnets
}

resource "aws_db_instance" "app_db" {
  identifier = "${var.app_name}-${var.stage}-db"
  storage_encrypted = true
  engine               = "mysql"
  allocated_storage    = 20
  max_allocated_storage = 100
  db_name              = var.db_name
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.app_db_subnet_group.name
  backup_retention_period = 30
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  multi_az = false
  parameter_group_name = aws_db_parameter_group.app_db_pg.name
  port = local.db_port
  vpc_security_group_ids = [aws_security_group.app_db_sg.id]
  storage_type = "gp3"
  network_type = "IPV4"
  username = var.db_user
  password = var.db_password
  skip_final_snapshot  = true
  deletion_protection = true

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}


#
# DBのログイン情報を保持する SecretsManager
#
resource "aws_secretsmanager_secret" "app_db_secret" {
  name = "/${var.app_name}/${var.stage}/db"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "app_db_secret_version" {
  secret_id = aws_secretsmanager_secret.app_db_secret.id
  secret_string = jsonencode({
    db_user = var.db_user
    db_password = var.db_password
    db_host = aws_db_instance.app_db.address
    db_port = aws_db_instance.app_db.port
  })
}

*/