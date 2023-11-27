#!/bin/bash

set -ex

ROOT_DIR="$(cd $(dirname $0)/..; pwd)"
export $(cat env/local.env | xargs)

docker rm -f terraform-tutorial-localstack

# https://docs.localstack.cloud/getting-started/installation/#docker
# 4566, 4510-4559 ポートを専有する
docker run \
  -d \
  --rm \
  --name terraform-tutorial-localstack \
  --network host \
  localstack/localstack


# secretsmanager
secret_file=$(mktemp)
cat <<EOF > $secret_file
{
  "db_host":"$DB_HOST",
  "db_password":"$DB_PASSWORD",
  "db_port":$DB_PORT,
  "db_user":"$DB_USER"
}
EOF
awslocal secretsmanager create-secret \
  --name "/terraform-tutorial/local/db" \
  --secret-string file://${secret_file}

# sns
awslocal sns create-topic \
  --name terraform-tutorial-local-topic

# sqs
awslocal sqs create-queue \
  --queue-name terraform-tutorial-fibonacci_job_queue
