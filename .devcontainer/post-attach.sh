#!/bin/bash

set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)

echo "{}" > $HOME/.docker/config.json