FROM public.ecr.aws/lambda/nodejs:22

USER root

RUN dnf install -y zip

WORKDIR /usr/src/layer

COPY package.json .

RUN npm install

RUN mkdir -p nodejs/node22/
RUN cp -r node_modules nodejs/node22/
RUN zip -r lambda-otel-layer.zip nodejs
