variable "app_name" {}
variable "stage" {}
variable "aws_region" {}
variable "account_id" {}

// CodeBuildのコンテナを実行するVPC
variable "vpc_id" {}

// CodeBuildのコンテナを実行するサブネット
variable "subnets" { type = list(string) }

// アプリのイメージURI (CodeBuildの環境変数に設定する)
variable "app_image_uri" {}

// ECSのクラスタ名
variable "ecs_cluster_name" {}

// ECSのサービス名
variable "ecs_service_name" {}

// 本番用のターゲットグループ
variable "app_tg_1_name" {}

// スタンバイ用のターゲットグループ
variable "app_tg_2_name" {}

// 本番用のリスナーARN
variable "lb_listener_green_arn" {}

// スタンバイ用のリスナーARN
variable "lb_listener_blue_arn" {}

// CodePipelineのアーティファクトを格納するS3バケット
variable "cicd_artifact_bucket" {}

// ECRのリポジトリ名
variable "repository_name" {}

// ECSのタスク定義名
variable "ecs_task_family" {}