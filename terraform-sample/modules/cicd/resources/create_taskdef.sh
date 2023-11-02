#!/bin/bash


function usage {
cat >&2 << EOS
現在稼働しているサービスのタスク定義を取得して、新しいタスク定義を作成する。
ここで生成したタスク定義は CodePipeline 側で appspec.yml の <TASK_DEFINITION> に展開される

詳しくはこちら: https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-taskdefinition


やっていることはイメージ名を IMAGE1_NAME に置換するだけ。
※ IMAGE1_NAME は CodePipeline 側で imageDetail.jsonのImageURIに置換されます

詳しくはこちら: https://dev.classmethod.jp/articles/ecs-deploytype-files/#toc-4

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

# aws ecs register-task-definition で必用な項目だけ抜き出す
AWS_CLI_QUERY="taskDefinition.{\
family:family, \
taskRoleArn:taskRoleArn, \
executionRoleArn:executionRoleArn, \
networkMode:networkMode, \
containerDefinitions:containerDefinitions, \
volumes:volumes, \
placementConstraints:placementConstraints, \
requiresCompatibilities:requiresCompatibilities, \
cpu:cpu, \
memory:memory, \
tags:tags, \
pidMode:pidMode, \
ipcMode:ipcMode, \
proxyConfiguration:proxyConfiguration, \
inferenceAccelerators:inferenceAccelerators, \
ephemeralStorage:ephemeralStorage\
}"

# 値がnullの項目を削除
JQ_QUERY_1='del(.[] | select(.==null))'

# イメージ名を IMAGE1_NAME に置換 (※ CodeDeploy側で imageDetail.jsonのImageURIに置換される)
JQ_QUERY_2='.containerDefinitions[0].image="<IMAGE1_NAME>"'

aws ecs describe-task-definition \
  --task-definition $TASK_DEFINITION_NAME \
  --query "$AWS_CLI_QUERY" \
  --output json |
jq -r "$JQ_QUERY_1" |
jq -r "$JQ_QUERY_2"
