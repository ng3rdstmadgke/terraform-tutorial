

```bash
STAGE=dev
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION="ap-northeast-1"
```

# ■ ECRリポジトリの作成 ~ プッシュ

```bash
REPOSITORY_NAME="terraform-tutorial/${STAGE}/app"

# リポジトリ作成
aws ecr create-repository --repository-name $REPOSITORY_NAME


# イメージのビルド
docker build --rm -f docker/app/Dockerfile -t ${REPOSITORY_NAME}:latest .

# ECRにログイン
mv -f /home/vscode/.docker/config.json /home/vscode/.docker/config.json.back  # 初期配置のconfig.jsonではログインできない
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# ECRにイメージをpush
REMOTE_REPOSITORY_NAME=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:latest
docker tag ${REPOSITORY_NAME}:latest $REMOTE_REPOSITORY_NAME
docker push $REMOTE_REPOSITORY_NAME
```

# ■ tfstate管理用s3バケット作成

```bash
# tfstateファイルをS3で管理する
# https://developer.hashicorp.com/terraform/language/settings/backends/s3
TFSTATE_BUCKET="terraform-tutorial-tfstate-store-a5gnpkub"

aws s3api create-bucket \
  --bucket $TFSTATE_BUCKET \
  --region $AWS_REGION \
  --create-bucket-configuration LocationConstraint=$AWS_REGION

```

# ■ tfstateロック用のdynamodbテーブルを作成

```bash
# tfstateファイルのロック情報をDynamoDBで管理する
# https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking

TFSTATE_LOCK_TABLE="terraform-tutorial-tfstate-lock"

aws dynamodb create-table \
    --table-name $TFSTATE_LOCK_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $AWS_REGION
```

# ■ terraformデプロイ

```bash
cd terraform-sample/envs/dev
terraform init
terraform plan
terraform apply -auto-approve
```

# ■ リソースの削除

```bash
cd terraform-sample/envs/dev

# すべて削除
terraform destroy

# アプリリソースのみ削除
terraform destroy -target=module.app
```