#!/bin/bash

set -ex

echo "=== === === === === === ls -alF === === === === === ==="
ls -alF
echo "=== === === === === === pwd === === === === === ==="
pwd

PROJECT_ROOT=$(cd $(dirname $0)/..; pwd)
cd $PROJECT_ROOT

cat <<EOF > ~/.bashrc

source ${CONTAINER_PROJECT_ROOT}/.devcontainer/.bashrc_private
EOF