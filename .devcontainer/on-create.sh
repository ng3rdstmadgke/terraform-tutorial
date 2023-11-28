#!/bin/bash

set -ex
echo "=== === === === === === on-create.sh === === === === === ==="
echo "=== === === === === === ls -alF === === === === === ==="
ls -alF
echo "=== === === === === === pwd === === === === === ==="
pwd
echo "=== === === === === === ls -alF .. === === === === === ==="
ls -alF ..

PROJECT_ROOT=$(cd $(dirname $0)/..; pwd)
cd $PROJECT_ROOT
pip install -r .devcontainer/requirements-dev.txt