#!/bin/bash
function usage {
cat >&2 << EOS
appspec.yamlを生成する

$0 <ECS_CLUSTER_NAME> <ECS_SERVICE_NAME>
EOS
exit 1
}

args=()
while [ "$#" != 0 ]; do
  case $1 in
    -* | --* ) echo "$1 : 不正なオプションです" >&2; exit 1;;
    *        ) args+=("$1");;
  esac
  shift
done

jq --version >/dev/null 2>&1 || { echo "jqがインストールされていません" >&2; exit 1; }

[ "${#args[@]}" != 2 ] && usage

set -ueo pipefail
ECS_CLUSTER_NAME=${args[0]}
ECS_SERVICE_NAME=${args[1]}

# 現在本番に適用されているタスク定義を取得
TASK_DEFINITION_NAME=$(aws ecs describe-services \
  --cluster $ECS_CLUSTER_NAME \
  --services $ECS_SERVICE_NAME \
  --query "services[0].taskDefinition" \
  --output text)

TASK_DEFINITION=$(aws ecs describe-task-definition \
  --task-definition $TASK_DEFINITION_NAME \
  --output json)

CONTAINER_NAME=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.containerDefinitions[0].name')
CONTAINER_PORT=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.containerDefinitions[0].portMappings[0].containerPort')

# AppSpecAmazon ECS デプロイメントのファイル構造
#   https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/reference-appspec-file-structure.html#ecs-appspec-structure
cat << EOS
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "$CONTAINER_NAME"
          ContainerPort: $CONTAINER_PORT
        PlatformVersion: "1.4.0"
EOS