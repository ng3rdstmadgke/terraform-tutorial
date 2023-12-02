#!/bin/bash

# LocalStack - init-fooks: https://docs.localstack.cloud/references/init-hooks/
# デバッグコマンド: docker logs terraform-tutorial_devcontainer-localstack-1  | less
set -ex

printenv

APP_NAME=terraform-tutorial
STAGE=local
REGION=ap-northeast-1

# secretsmanager
secret_file=$(mktemp)
cat <<EOF > $secret_file
{
  "db_host": "${DB_HOST}",
  "db_password": "${DB_PASSWORD}",
  "db_port": "${DB_PORT}",
  "db_user": "${DB_USER}"
}
EOF
awslocal secretsmanager create-secret \
  --region ${REGION} \
  --name "/${APP_NAME}/${STAGE}/db" \
  --secret-string file://${secret_file}

# sns
awslocal sns create-topic \
  --region ${REGION} \
  --name ${APP_NAME}-${STAGE}-topic

# sqs
awslocal sqs create-queue \
  --region ${REGION} \
  --queue-name ${APP_NAME}-${STAGE}-job_queue
