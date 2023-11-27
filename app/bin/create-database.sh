#!/bin/bash

set -ex

if [ -z "$LOCAL" ]; then
  SECRET_STRING="$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_NAME" --query 'SecretString' --output text)"
  DB_PASSWORD=$(echo "$SECRET_STRING" | jq -r '.db_password')
  DB_USER=$(echo "$SECRET_STRING" | jq -r '.db_user')
  DB_HOST=$(echo "$SECRET_STRING" | jq -r '.db_host')
  DB_PORT=$(echo "$SECRET_STRING" | jq -r '.db_port')
  DB_NAME=$(echo $DB_NAME)
fi

# データベースを削除
MYSQL_PWD=$DB_PASSWORD mysql -u $DB_USER -h $DB_HOST -P $DB_PORT -e "DROP DATABASE IF EXISTS $DB_NAME"

# データベースを作成
MYSQL_PWD=$DB_PASSWORD mysql -u $DB_USER -h $DB_HOST -P $DB_PORT -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"