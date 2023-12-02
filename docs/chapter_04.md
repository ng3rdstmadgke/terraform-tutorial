Chapter4 オンデマンドジョブ
---
[READMEに戻る](../README.md)

# ■ 1. 作るもの

job_baseモジュールで作成したコンピューティング環境で動作するAWS Batchと、AWS Batch, lambdaを一連の処理として定義するStepFunctions、StepFunctionsをキックするためのSQSの作成を行います。  

オンデマンドジョブは、Webアプリから好きなときに起動できるジョブという位置づけです。

<img src="img/04/drawio/architecture.drawio.png" width="900px">

# ■ 2. on_demand_jobモジュールの作成

## 1. ファイルの作成

`on_demand_job` モジュールを定義します。

```bash
ENV_NAME="your_name"
mkdir -p ${CONTAINER_PROJECT_ROOT}/terraform/modules/on_demand_job
touch ${CONTAINER_PROJECT_ROOT}/terraform/modules/on_demand_job/{main.tf,variables.tf,outputs.tf,iam.tf}
```

## 2. 入力値・出力値の定義

`terraform/modules/on_demand_job/variables.tf`

```hcl
```

`terraform/modules/on_demand_job/outputs.tf`

```hcl
```

## 3. リソース定義

`terraform/modules/on_demand_job/main.tf`

```hcl
```

`terraform/modules/on_demand_job/iam.tf`

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