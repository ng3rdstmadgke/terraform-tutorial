#!/bin/bash

make -C ${CONTAINER_PROJECT_ROOT}/app clean
make -C ${CONTAINER_PROJECT_ROOT}/app package
