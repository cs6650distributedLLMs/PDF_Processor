#!/usr/bin/env sh

set -x

docker build -t sharp-layer-builder .
docker create --name sharp-layer sharp-layer-builder
docker cp sharp-layer:/usr/src/layer/lambda-sharp-layer.zip .
docker rm -f sharp-layer
