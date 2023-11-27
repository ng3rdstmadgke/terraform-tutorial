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
EOF
exit 1
}

ROOT_DIR="$(cd $(dirname $0)/..; pwd)"

ENV_PATH="${ROOT_DIR}/env/local.env"
args=()
while [ "$#" != 0 ]; do
  case $1 in
    -h | --help     ) usage ;;
    -e | --env-file ) shift; ENV_PATH="$1" ;;
    -* | --*        ) echo "不正なオプション: $1" >&2; exit 1 ;;
    *               ) args+=("$1") ;;
  esac
  shift
done

[ "${#args[@]}" != 0 ] && usage

ENV_ABS_PATH=$(cd $(dirname $ENV_PATH); pwd)/$(basename $ENV_PATH)
if [ ! -f "$ENV_ABS_PATH" ]; then
  echo "$ENV_ABS_PATH が存在しません" >&2
  exit 1
fi

set -e
cd $ROOT_DIR

docker build \
  --rm \
  -f docker/app/Dockerfile \
  -t terraform-tutorial/local/app:latest .

docker run \
  --rm \
  -ti \
  -v ${HOST_PROJECT_ROOT}/app:/opt/app \
  --env-file $ENV_ABS_PATH \
  --network host \
  -p "80:80" \
  terraform-tutorial/local/app:latest
