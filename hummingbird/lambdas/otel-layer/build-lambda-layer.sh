#!/usr/bin/env sh

set -x

docker build -t otel-layer-builder .
docker create --name otel-layer otel-layer-builder
docker cp otel-layer:/usr/src/layer/layer-content.zip .
docker rm -f otel-layer
