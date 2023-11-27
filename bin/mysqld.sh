#!/bin/bash


ROOT_DIR="$(cd $(dirname $0)/..; pwd)"
cd $ROOT_DIR

ENV_PATH="${ROOT_DIR}/env/local.env"

export $(cat $ENV_PATH | grep -v -e "^ *#")

set -e

docker build \
  --rm \
  -f docker/mysql/Dockerfile \
  -t terraform-tutorial/local/mysql:latest \
  .

# docker run
docker rm -f terraform-tutorial-mysql

docker run \
  -d \
  --rm \
  --network host \
  --name terraform-tutorial-mysql \
  -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD \
  -e MYSQL_DATABASE=$DB_NAME \
  terraform-tutorial/local/mysql:latest

docker run \
  --rm \
  --network host \
  --env-file "$ENV_PATH" \
  terraform-tutorial/local/mysql:latest \
  /check.sh