/**
 * 参考
 * - チュートリアル:Amazon ECR ソースと ECS to-デプロイを使用してパイプラインを作成する CodeDeploy
 * https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-taskdefinition
 */

/**
 * CodeBuild
 */
# CodeBuild用セキュリティグループ
resource "aws_security_group" "codebuild_sg" {
  name = "${var.app_name}-${var.stage}-app-CodeBuild-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
     Name = "${var.app_name}-${var.stage}-app-CodeBuild-sg"
  }
}

 # ロググループ
resource "aws_cloudwatch_log_group" "codebuild" {
  name = "${var.app_name}/${var.stage}/app/codebuild"
  retention_in_days = 365
}

# aws_codebuild_project | Terraform:
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
# AWS::CodeBuild::Project | CloudFormation:
#   https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/aws-resource-codebuild-project.html
resource "aws_codebuild_project" "this" {
  name          = "${var.app_name}-${var.stage}-app"
  description   = "Build app image and push to ECR"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type            = "CODEPIPELINE"
    git_clone_depth = 0
    buildspec       = file("../../modules/cicd/resources/buildspec.yml")
  }

  environment {
    # BUILD_GENERAL1_SMALL : 3GB memory  2 vCPUs
    # BUILD_GENERAL1_MEDIUM: 7GB memory  4 vCPUs
    # BUILD_GENERAL1_LARGE : 15GB memory 8 vCPUs
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    # CodeBuildに用意されているDockerイメージ
    #   https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/build-env-ref-available.html
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    # 特権モードでコンテナを起動
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }
    environment_variable {
      name  = "APP_IMAGE_URI"
      value = var.app_image_uri
    }
    environment_variable {
      name  = "ECS_CLUSTER_NAME"
      value = var.ecs_cluster_name
    }
    environment_variable {
      name  = "ECS_SERVICE_NAME"
      value = var.ecs_service_name
    }
  }

  vpc_config {
    vpc_id = var.vpc_id
    subnets = var.subnets
    security_group_ids = [ aws_security_group.codebuild_sg.id ]
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = ""
    }
  }
  depends_on = [
    aws_iam_policy.codebuild_service_policy,
    aws_iam_policy.codebuild_for_vpc_policy,
    aws_iam_policy.codebuild_for_ssm_policy,
    aws_iam_policy.codebuild_for_app_policy,
  ]
}


/**
 * CodeDeploy
 *
 * CodeDeployによるBlue-Greenデプロイ:
 *   https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/deployment-type-bluegreen.html
 */
resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = "${var.app_name}-${var.stage}-app"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  # トラトラフィックの切り替え方式
  # https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/deployment-type-bluegreen.html
  # - CodeDeployDefault.ECSAllAtOnce                    : すべてのトラフィックを切り替え
  # - CodeDeployDefault.ECSLinear10PercentEvery1Minutes : 1分ごとに10%ずつ切り替え
  # - CodeDeployDefault.ECSLinear10PercentEvery3Minutes : 3分ごとに10%ずつ切り替え
  # - CodeDeployDefault.ECSCanary10Percent5Minutes      : 10%を切り替えて、5分後に残りの90%を切り替え
  # - CodeDeployDefault.ECSCanary10Percent15Minutes     : 10%を切り替えて、5分後に残りの90%を切り替え
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${var.app_name}-${var.stage}-app"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  # ALBの設定
  load_balancer_info {
    target_group_pair_info {
      # 本番用のリスナー (HTTPS:443)
      prod_traffic_route {
        listener_arns = [ var.lb_listener_green_arn ]
      }

      # テスト用のリスナー (HTTP:8080)
      test_traffic_route {
        listener_arns = [ var.lb_listener_blue_arn ]
      }

      # ターゲットグループ1
      target_group { name = var.app_tg_1_name }
      # ターゲットグループ2
      target_group { name = var.app_tg_2_name }
    }
  }

  # デプロイ方式
  deployment_style {
    # WITH_TRAFFIC_CONTROL or WITHOUT_TRAFFIC_CONTROL
    deployment_option = "WITH_TRAFFIC_CONTROL"  # LBを利用したトラフィックの切り替えを行う
    # IN_PLACE or BLUE_GREEN
    deployment_type   = "BLUE_GREEN"  # Blue/Greenデプロイを行う
  }

  blue_green_deployment_config {
    deployment_ready_option {
      # 10分以内にトラフィックを手動で切り替えなかった場合デプロイが停止する
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 300
    }
    /*
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    */

    # デプロイ成功時のBlue環境の削除設定
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 60
    }
  }

  # デプロイのロールバック設定
  auto_rollback_configuration {
    enabled = true
    # デプロイに失敗したとき
    events  = ["DEPLOYMENT_FAILURE"]
  }

}

/**
 * CodePipeline
 *
 * CodePipelineの構造
 *   https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/reference-pipeline-structure.html
 */

resource "aws_codepipeline" "this" {
  name     = "${var.app_name}-${var.stage}-app"
  role_arn = aws_iam_role.codepipeline_service_role.arn

  artifact_store {
    location = var.cicd_artifact_bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    # CodeCommit アクションリファレンス:
    # https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/action-reference-CodeCommit.html
    action {
      run_order        = 1
      name             = "Source"
      # アクションカテゴリにはSource, Build, Test, Deploy, Approval, Invokeのいずれかを指定する
      # Source: CodeCommit, S3, ECR, etc...
      # Build: CodeBuild, Jenkins, etc...
      # Deploy: CodeDeploy, CloudFormation, etc...
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"  # 書き方のバージョン (1で固定)
      output_artifacts = ["SourceArtifact"]

      configuration = {
        # ソースの変更が検出されるリポジトリ
        RepositoryName       = var.repository_name
        # ソースの変更が検出されるブランチ名
        BranchName           = var.stage
      }
    }
  }

  stage {
    name = "Build"

    # CodeBuild アクションリファレンス:　
    # https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/action-reference-CodeBuild.html
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"  # 書き方のバージョン (1で固定)
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    # ECS Blue-Greenデプロイ用 CodeDeploy アクションリファレンス:　
    #   https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/action-reference-ECSbluegreen.html
    action {
      name      = "Deploy"
      category  = "Deploy"
      owner     = "AWS"
      provider  = "CodeDeployToECS"
      region    = var.aws_region
      run_order = 1
      version   = "1"
      # ECSのローリングアップデートとブルー/グリーンデプロイで利用するファイルの比較
      #   https://dev.classmethod.jp/articles/ecs-deploytype-files/#toc-8
      #
      # Blue-Greenデプロイの入力として必要なファイルは
      # imageDetail.json, taskdef.json, appspec.yamlの3つ
      input_artifacts = ["BuildArtifact"]

      configuration = {
        # CodeDeployアプリケーション
        ApplicationName                = aws_codedeploy_app.this.name
        # ECSサービスに設定されているデプロイグループ
        DeploymentGroupName            = aws_codedeploy_deployment_group.this.app_name
        # タスク定義ファイル(taskdef.json)を提供する入力アーティファクトの名前 (ソースアクションの出力アーティファクト名)
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        # AppSpecファイル(appspec.yaml)を提供する入力アーティファクトの名前 (ソースアクションの出力アーティファクト名)
        AppSpecTemplateArtifact        = "BuildArtifact"
        # イメージ定義ファイル(imageDetail.json)を提供する入力アーティファクトの名前 (ソースアクションの出力アーティファクト名)
        Image1ArtifactName             = "BuildArtifact"
        # taskdef.json内で利用できるプレースホルダを定義。
        # taskdef.json内でこのプレースホルダを利用すると、imageDetail.jsonのImageURIに置換される。
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }

  depends_on = [
    aws_iam_policy.codepipeline_service_policy
  ]

}