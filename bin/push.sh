#!/bin/bash
set -e
ROOT_DIR="$(cd $(dirname $0)/..; pwd)"
cd $ROOT_DIR
docker build --rm -f docker/Dockerfile -t test-app:latest .

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com


docker tag test-app:latest ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/test-app:latest
docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/test-app:latest

VERSION=$(date +"%Y%m%d.%H%M")
docker tag test-app:latest ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/test-app:${VERSION}
docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/test-app:${VERSION}

echo "VERSION: ${VERSION}"
