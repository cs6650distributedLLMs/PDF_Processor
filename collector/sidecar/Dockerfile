FROM amazon/aws-otel-collector:v0.43.0 AS adot-base

FROM alpine:latest

# Default AWS region. To be replaced by the actual region where the container is deployed.
ENV AWS_REGION=us-west-2

ENV OTEL_SIDECAR_GRPC_PORT=4319
ENV OTEL_SIDECAR_HTTP_PORT=4320
ENV OTEL_COLLECTOR_DIR_PATH="/opt/aws/aws-otel-collector"
ENV OTEL_COLLECTOR_BIN_PATH="${OTEL_COLLECTOR_DIR_PATH}/bin/aws-otel-collector"
ENV OTEL_SIDECAR_LOG_LEVEL="INFO"

USER root

COPY --from=adot-base /awscollector ${OTEL_COLLECTOR_BIN_PATH}

RUN apk add --no-cache bash curl

WORKDIR /collector

COPY entrypoint.sh .
COPY config.yaml .
COPY config-with-ecs-metrics.yaml .

RUN addgroup -S otel && adduser -S otel -G otel
RUN chown -R otel:otel /collector
RUN chown -R otel:otel ${OTEL_COLLECTOR_DIR_PATH}

EXPOSE ${OTEL_SIDECAR_GRPC_PORT} ${OTEL_SIDECAR_HTTP_PORT}

USER otel

ENTRYPOINT ["/collector/entrypoint.sh"]
