#!/bin/bash

set -e
SCRIPT_DIR=$(cd $(dirname $0); pwd)
source $SCRIPT_DIR/lib/settings.sh

set -x
# データベースを削除
MYSQL_PWD=$DB_PASSWORD mysql -u $DB_USER -h $DB_HOST -P $DB_PORT -e "DROP DATABASE IF EXISTS $DB_NAME"

# データベースを作成
MYSQL_PWD=$DB_PASSWORD mysql -u $DB_USER -h $DB_HOST -P $DB_PORT -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"

# マイグレーション
(cd $SCRIPT_DIR/..; alembic upgrade head)