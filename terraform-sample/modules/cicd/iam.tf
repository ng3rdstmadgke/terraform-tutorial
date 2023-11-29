/**
 * CodeBuildサービスロール
 */

resource "aws_iam_role" "codebuild_service_role" {
  name = "${var.app_name}-${var.stage}-CodeBuildServiceRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codebuild.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  lifecycle {
    // NOTE: CICDアーティファクト用バケットのバケットポリシーのConditionにRoleIdを利用しているので削除してはいけない
    // prevent_destroy = true
  }
}

// CodeBuildサービスロールの作成
// https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/setting-up.html#setting-up-service-role
resource "aws_iam_policy" "codebuild_service_policy" {
  name = "${var.app_name}-${var.stage}-CodeBuildServicePolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "CloudWatchLogsPolicy",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "CodeCommitPolicy",
        "Effect" : "Allow",
        "Action" : [
          "codecommit:GitPull"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "S3GetObjectPolicy",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "S3PutObjectPolicy",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "ECRPullPolicy",
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "ECRAuthPolicy",
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "S3BucketIdentity",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codebuild_service_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_service_policy.arn
}

// VPC内でCodeBuildを実行するためのポリシー
// https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/auth-and-access-control-iam-identity-based-access-control.html#customer-managed-policies-example-create-vpc-network-interface
resource "aws_iam_policy" "codebuild_for_vpc_policy" {
  name = "${var.app_name}-${var.stage}-CodeBuildForVpcPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterfacePermission"
        ],
        "Resource" : "arn:aws:ec2:${var.aws_region}:${var.account_id}:network-interface/*",
        "Condition" : {
          "StringEquals" : {
            "ec2:AuthorizedService" : "codebuild.amazonaws.com"
          },
          "ArnEquals" : {
            "ec2:Subnet" : [
              for subnet in var.subnets : "arn:aws:ec2:${var.aws_region}:${var.account_id}:subnet/${subnet}"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codebuild_for_vpc_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_for_vpc_policy.arn
}

// セッションマネージャーでビルド中のコンテナに接続するためのポリシー
// https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/session-manager.html
resource "aws_iam_policy" "codebuild_for_ssm_policy" {
  name = "${var.app_name}-${var.stage}-CodeBuildForSsmPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "logs:DescribeLogGroups",
        "Resource" : "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:*:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${aws_cloudwatch_log_group.codebuild.name}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codebuild_for_ssm_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_for_ssm_policy.arn
}


// そのほか必用なポリシー
resource "aws_iam_policy" "codebuild_for_app_policy" {
  name = "${var.app_name}-${var.stage}-CodeBuildForAppPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource" : [
          "arn:aws:secretsmanager:ap-northeast-1:${var.account_id}:secret:/${var.app_name}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:Describe*"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codebuild_for_app_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_for_app_policy.arn
}

/**
 * CodeDeployサービスロール
 */
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.app_name}-${var.stage}-CodeDeployServiceRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codedeploy.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  lifecycle {
    // NOTE: CICDアーティファクト用バケットのバケットポリシーのConditionにRoleIdを利用しているので削除してはいけない
    // prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "attach_codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}


/**
 * CodePipelineサービスロール
 */
resource "aws_iam_role" "codepipeline_service_role" {
  name = "${var.app_name}-${var.stage}-CodePipelineServiceRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codepipeline.amazonaws.com",
        },
        "Action" : "sts:AssumeRole",
      }
    ]
  })
  lifecycle {
    // NOTE: CICDアーティファクト用バケットのバケットポリシーのConditionにRoleIdを利用しているので削除してはいけない
    // prevent_destroy = true
  }
}

resource "aws_iam_policy" "codepipeline_service_policy" {
  name = "${var.app_name}-${var.stage}-CodePipelineServicePolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "iam:PassRole"
        ],
        "Resource" : "*",
        "Effect" : "Allow",
        "Condition" : {
          "StringEqualsIfExists" : {
            "iam:PassedToService" : [
              "cloudformation.amazonaws.com",
              "elasticbeanstalk.amazonaws.com",
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        "Action" : [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "opsworks:CreateDeployment",
          "opsworks:DescribeApps",
          "opsworks:DescribeCommands",
          "opsworks:DescribeDeployments",
          "opsworks:DescribeInstances",
          "opsworks:DescribeStacks",
          "opsworks:UpdateApp",
          "opsworks:UpdateStack"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "devicefarm:ListProjects",
          "devicefarm:ListDevicePools",
          "devicefarm:GetRun",
          "devicefarm:GetUpload",
          "devicefarm:CreateUpload",
          "devicefarm:ScheduleRun"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudformation:ValidateTemplate"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:DescribeImages"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codepipeline_service_policy" {
  role       = aws_iam_role.codepipeline_service_role.name
  policy_arn = aws_iam_policy.codepipeline_service_policy.arn
}

/**
 * CodePipelineのトリガーとして利用するEventBridgeのサービスロール
 */
resource "aws_iam_role" "event_bridge_codepipeline" {
  name = "${var.app_name}-${var.stage}-EventBridgeCodepipelineTrigerRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "events.amazonaws.com",
        },
        "Action" : "sts:AssumeRole",
      }
    ]
  })
}
resource "aws_iam_policy" "event_bridge_codepipeline_policy" {
  name = "${var.app_name}-${var.stage}-EventBridgeCodepipelineTrigerPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "codepipeline:StartPipelineExecution"
        ],
        "Resource" : [
          "${aws_codepipeline.this.arn}"
        ],
        "Effect" : "Allow"
      }
    ]

  })
}

resource "aws_iam_role_policy_attachment" "attach_event_bridge_codepipeline_policy" {
  role       = aws_iam_role.event_bridge_codepipeline.name
  policy_arn = aws_iam_policy.event_bridge_codepipeline_policy.arn
}