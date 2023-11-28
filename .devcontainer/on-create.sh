#!/bin/bash

set -ex

echo "=== === === === === === ls -alF === === === === === ==="
ls -alF
echo "=== === === === === === pwd === === === === === ==="
pwd

PROJECT_ROOT=$(cd $(dirname $0)/..; pwd)
cd $PROJECT_ROOT
pip install -r .devcontainer/requirements-dev.txt