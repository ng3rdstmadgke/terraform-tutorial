#!/bin/bash
set -e
ROOT_DIR="$(cd $(dirname $0)/..; pwd)"
cd $ROOT_DIR
docker build --rm -f docker/Dockerfile -t test-app:latest .
docker run  --rm -ti --network host test-app:latest
