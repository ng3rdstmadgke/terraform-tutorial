Chapter6 ロードバランサー
---
[READMEに戻る](../README.md)

# ■ 1. 作るもの

この章ではロードバランサーを作成します。

<img src="img/06/drawio/architecture.drawio.png" width="900px">


# ■ 2. モジュールの作成

リソースはある程度ライフサイクルが近いリソースをグループ化した、モジュールという単位で定義していきます。  
モジュールには主に3つのファイルを定義します。

1. `main.tf`  
作成するリソースを定義するファイルです
2. `variables.tf`  
モジュールのデプロイに必要な入力値(引数) を定義するファイルです
3. `outputs.tf`  
モジュールの外で利用したい出力値(戻り値) を定義するファイルです


```bash
mkdir -p terraform terraform/modules/alb
( cd terraform/modules/alb; touch main.tf variables.tf outputs.tf)
```


# ■ 3. 入力値・出力値の定義

`terraform/modules/alb/variables.tf`

```hcl
variable "app_name" {}
variable "stage" {}

// セキュリティグループが所属するVPC
variable "vpc_id" {}

// ALBが所属するサブネット
variable "alb_subnets" {
  type = list(string)
}

// ALBがアクセスを許可するIPアドレス
variable "ingress_rules_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
```

`terraform/modules/alb/outputs.tf`

```tf
// 作成したALBリソース
output "app_alb" {
  value = aws_lb.app_alb
}
```


# ■ 4. リソース定義


ALBとそのセキュリティグループを作成します。  
※ ALBは再作成が走るとURLが変わってしまうため、本番で利用する場合は `lifecycle.prevent_destroy = true` を設定するとよいです。 (個人的には気づかないで変更してしまうことも避けたいので `lifecycle.ignore_changes = all` を設定しています。この辺はお好みで。)  


`terraform/modules/alb/main.tf`

```hcl
/**
 * ALB用セキュリティグループ
 * aws_security_group: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
 */
resource "aws_security_group" "app_alb_sg" {
  name   = "${var.app_name}-${var.stage}-app-alb-sg"
  vpc_id = var.vpc_id

  // HTTPアクセスを許可
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_rules_cidr_blocks
  }
  // Blue/Greenデプロイのテストトラフィックルーティングで利用するポート
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.ingress_rules_cidr_blocks
  }
  // HTTPSアクセスを許可
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
  internal           = false  // privateサブネットにALBを作成する場合はtrue

  lifecycle {
    # terraformの変更を適用しない
    # https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#ignore_changes
    ignore_changes = all
    # 強制的なリソースの再作成が起こらないようにする (本番環境では有効化)
    # https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#prevent_destroy
    #prevent_destroy = true
  }
}

```

# ■ 5. 定義したモジュールをエントリーポイントから参照する

`terraform/envs/${ENV_NAME}/main.tf`

```hcl
// ... 略 ...

// 変数定義
variable "vpc_id" { type = string }
variable "alb_subnets" { type = list(string) }

// ローカル変数を定義
locals {
  aws_region      = data.aws_region.current.name
  account_id      = data.aws_caller_identity.self.account_id
  app_name        = replace(lower("terraformtutorial"), "-", "")
  stage           = "ステージ名"
}

// 出力
output "alb_host_name" {
  value = module.alb.app_alb.dns_name
}

// albモジュールを利用
module "alb" {
  source      = "../../modules/alb"
  app_name    = local.app_name
  stage       = local.stage
  vpc_id      = var.vpc_id
  alb_subnets = var.alb_subnets
}
```

variable で宣言した変数は `terraform apply` 実行時にインタラクティブに指定してもいいですが、今回は `environment.auto.tfvars` を利用して指定してみましょう。
`*.auto.tfvars` で宣言した値は自動的に変数としてアサインされます。

```bash
touch terraform/envs/${ENV_NAME}/environment.auto.tfvars
```

`terraform/envs/${ENV_NAME}/environment.auto.tfvars`

```hcl
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"

// ALBを配置するためのサブネット (public)
alb_subnets = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]
```

# ■ 6. デプロイ

```bash
cd terraform/envs/${ENV_NAME}

# 初期化
terraform init

# デプロイ内容確認
terraform plan

# 作成
terraform apply -auto-approve
```