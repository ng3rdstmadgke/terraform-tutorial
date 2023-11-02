# terraformで利用できる関数

- [Build-in Functions | terraform](https://developer.hashicorp.com/terraform/language/functions)


# プロキシ設定

## http_proxy, https_proxy, no_proxy 環境変数設定

- buildspec.yml内のdocker build
- `cicd/main.tf` の `aws_codebuild_project` `environment` 
- `app/main.tf` の `aws_ecs_task_definition` `container_definitions.environment`

## CodeBuildで利用されるdockerプロセスにプロキシ設定を適用

```yaml:buildspec.yml
version: 0.2
phases:
  pre_build:
    commands:
      #- codebuild-breakpoint
      # CodeBuild内のDockerデーモンにProxy設定
      # https://qiita.com/yomon8/items/836b316448ba485fc919
      - docker system info
      - kill -9 $(cat /var/run/docker.pid)
      - while kill -0 $(cat /var/run/docker.pid) ; do sleep 1 ; done
      - /usr/local/bin/dockerd-entrypoint.sh
      - docker system info
```