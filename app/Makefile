# Makefileの関数一覧: https://tex2e.github.io/blog/makefile/functions

# MakefileのSyntax
# $<
#   特殊変数。ターゲットの依存リストの最初のアイテムを示す
# $@
#   特殊変数。現在のターゲットを示す
# .PHONY: パッケージ名
#   ファイルやディレクトリといった物理的存在を持たない疑似ターゲット。
#   `make パッケージ名` のように実行することで、ターゲット名と同名のファイルが存在していても、ターゲットの内容を実行する

.PHONY: package
.PHONY: build
.PHONY: clean

UID := $(shell id -u)
GID := $(shell id -g)
CONTAINER_BUILD_DIR := ${CONTAINER_PROJECT_ROOT}/.lambda-build
HOST_BUILD_DIR := ${HOST_PROJECT_ROOT}/.lambda-build
DOCKER_IMAGE := terraform-tutorial/local/lambda-build:latest
API_PYTHON_FILES := $(wildcard $(CONTAINER_PROJECT_ROOT)/app/api/**/*.py)

# $(foreach 変数,リスト,処理)
package: $(CONTAINER_BUILD_DIR)/layer $(CONTAINER_BUILD_DIR)/src

# app/api と app/lambda にあるファイルを .build/src にコピー
$(CONTAINER_BUILD_DIR)/src: $(API_PYTHON_FILES) $(CONTAINER_PROJECT_ROOT)/app/lambda/*.py
	rm -rf $@
	mkdir -p $@
	cp -r $(CONTAINER_PROJECT_ROOT)/app/api $@/api
	cp -r $(CONTAINER_PROJECT_ROOT)/app/lambda/* $@/

# .build/layer ディレクトリに lambda layer として利用するライブラリをインストール
$(CONTAINER_BUILD_DIR)/layer: $(CONTAINER_PROJECT_ROOT)/app/requirements.txt $(CONTAINER_BUILD_DIR)/.lambda-build
	rm -rf $@
	docker run --rm \
		--user $(UID):$(GID) \
		-v $(HOST_PROJECT_ROOT)/app:/opt/app \
		-v $(HOST_BUILD_DIR):/opt/.lambda-build \
		$(DOCKER_IMAGE) \
		pip install -r /opt/app/requirements.txt -t /opt/.lambda-build/layer/python


# lambda layer ビルド用のDockerイメージを作成
$(CONTAINER_BUILD_DIR)/.lambda-build: $(CONTAINER_PROJECT_ROOT)/docker/lambda-build/Dockerfile
	mkdir -p $(CONTAINER_BUILD_DIR)
	docker build --rm \
		--build-arg host_uid=$(UID) \
		--build-arg host_gid=$(GID) \
		-f $(CONTAINER_PROJECT_ROOT)/docker/lambda-build/Dockerfile \
		-t $(DOCKER_IMAGE) .
	touch $@

# お片付け
clean:
	rm -rf ${CONTAINER_BUILD_DIR}
	docker rmi $(DOCKER_IMAGE)