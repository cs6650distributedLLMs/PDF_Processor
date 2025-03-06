FROM alpine:latest

USER root

RUN apk add --no-cache bash curl

WORKDIR /collector

ENV OTEL_COLLECTOR_VERSION=0.98.0
ENV OTEL_COLLECTOR_TAR_FILE=otelcol-contrib_${OTEL_COLLECTOR_VERSION}_linux_amd64.tar.gz
ENV OTEL_COLLECTOR_BIN_PATH="/collector/otelcol-contrib"
ENV OTEL_COLLECTOR_CONFIG_PATH="/collector/config.yaml"
ENV OTEL_GATEWAY_LOG_LEVEL="INFO"
ENV OTEL_GATEWAY_GRPC_PORT=4317
ENV OTEL_GATEWAY_HTTP_PORT=4318

RUN curl --proto '=https' --tlsv1.2 -fOL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_COLLECTOR_VERSION}/${OTEL_COLLECTOR_TAR_FILE}
RUN tar -xvf ${OTEL_COLLECTOR_TAR_FILE}
RUN rm ${OTEL_COLLECTOR_TAR_FILE}

COPY entrypoint.sh .
COPY config.yaml .

RUN addgroup -S otel && adduser -S otel -G otel
RUN chown -R otel:otel /collector

EXPOSE ${OTEL_GATEWAY_GRPC_PORT} ${OTEL_GATEWAY_HTTP_PORT}

USER otel

ENTRYPOINT ["/collector/entrypoint.sh"]
