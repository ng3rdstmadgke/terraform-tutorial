Chapter5 スケジュールジョブ
---
[READMEに戻る](../README.md)

# ■ 1. 作るもの

job_baseモジュールで作成したコンピューティング環境で動作するAWS Batchと、AWS Batch, lambdaを一連の処理として定義するStepFunctions、StepFunctionsを定期実行するEventBridgeの作成を行います。  

スケジュールジョブは、cron的な定期実行の仕組みという位置づけです。

<img src="img/05/drawio/architecture.drawio.png" width="900px">

# ■ 2. scheduled_job モジュールの作成

## 1. ファイルの作成

`scheduled_job` モジュールを定義します。

```bash
ENV_NAME="your_name"
mkdir -p ${CONTAINER_PROJECT_ROOT}/terraform/modules/scheduled_job
touch ${CONTAINER_PROJECT_ROOT}/terraform/modules/scheduled_job/{main.tf,variables.tf,outputs.tf,iam.tf}
```

## 2. 入力値・出力値の定義

`terraform/modules/scheduled_job/variables.tf`

```hcl
```

`terraform/modules/scheduled_job/outputs.tf`

```hcl
```

## 3. リソース定義

`terraform/modules/scheduled_job/main.tf`

```hcl
```

`terraform/modules/scheduled_job/iam.tf`

```hcl
```

# ■ 4. 定義したモジュールをエントリーポイントから参照

`terraform/envs/${ENV_NAME}/main.tf`

```hcl
```

# ■ 5. デプロイ

```bash
cd ${CONTAINER_PROJECT_ROOT}/terraform/envs/${ENV_NAME}

# 初期化
terraform init

# デプロイ内容確認
terraform plan

# デプロイ
terraform apply -auto-approve
```