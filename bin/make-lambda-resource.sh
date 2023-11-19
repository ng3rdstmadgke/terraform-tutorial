#!/bin/bash
function usage {
cat <<EOF >&2
  $0 FUNCTION_NAME=xxxxxxxxxxxxx

  [vars]
    FUNCTION_NAME:
      lambdaの関数名
EOF
exit 1
}

while [ "$#" != 0 ]; do
  case $1 in
    -h | --help ) usage;;
  esac
  shift
done

set -ex
make -C ${CONTAINER_PROJECT_ROOT}/app clean $@
make -C ${CONTAINER_PROJECT_ROOT}/app package $@
