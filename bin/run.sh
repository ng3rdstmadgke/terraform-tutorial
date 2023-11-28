#!/bin/bash

function usage {
cat <<EOF >&2

[USAGE]
  $0 [OPTIONS]

[OPTIONS]
  -h | --help:
    ヘルプを表示
  -e | --env-file:
    環境変数ファイルを指定
  -m | --mode <app|shell>
    起動モードの選択 (default=app)
    app: fastapiを起動
    shell: /bin/bashを起動

[EXAMPLE]
  # mysql起動
  ./bin/mysqld.sh

  # localstack起動
  ./bin/local-stackd.sh

  # マイグレーション
  $0 -m shell
  ./bin/create-database.sh
  alembic upgrade head
  exit

  # アプリ起動
  $0


EOF
exit 1
}

ROOT_DIR="$(cd $(dirname $0)/..; pwd)"

MODE=app
ENV_PATH="${ROOT_DIR}/env/local.env"
args=()
while [ "$#" != 0 ]; do
  case $1 in
    -h | --help     ) usage ;;
    -e | --env-file ) shift; ENV_PATH="$1" ;;
    -m | --mode     ) shift; MODE="$1" ;;
    -* | --*        ) echo "不正なオプション: $1" >&2; exit 1 ;;
    *               ) args+=("$1") ;;
  esac
  shift
done

[ "${#args[@]}" != 0 ] && usage

ENV_ABS_PATH=$(cd $(dirname $ENV_PATH); pwd)/$(basename $ENV_PATH)
if [ ! -f "$ENV_ABS_PATH" ]; then
  echo "環境変数 $ENV_ABS_PATH が存在しません" >&2
  exit 1
fi

if [ "$MODE" != "app" -a "$MODE" != "shell" ]; then
  echo "MODE には app もしくは shell が指定可能です。" >&2
  exit 1
fi

set -e
cd $ROOT_DIR

docker build \
  --rm \
  -f docker/app/Dockerfile \
  -t terraform-tutorial/local/app:latest .

CONTAINER_NAME="terraform-tutorial-${MODE}"
CMD=

if [ "$MODE" = "app" ]; then
  docker run \
    --rm \
    -ti \
    --name terraform-tutorial-app \
    -v ${HOST_PROJECT_ROOT}/app:/opt/app \
    --env-file $ENV_ABS_PATH \
    --network br-terraform-tutorial \
    -p "80:80" \
    terraform-tutorial/local/app:latest
elif [ "$MODE" = "shell" ]; then
  docker run \
    --rm \
    -ti \
    -v ${HOST_PROJECT_ROOT}/app:/opt/app \
    --env-file $ENV_ABS_PATH \
    --network br-terraform-tutorial \
    terraform-tutorial/local/app:latest \
    /bin/bash
fi