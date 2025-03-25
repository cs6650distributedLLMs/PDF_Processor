FROM public.ecr.aws/lambda/nodejs:22

USER root

RUN dnf install -y zip

WORKDIR /usr/src/layer

RUN npm init -y
RUN npm install --include=optional --cpu=x64 --os=linux sharp

RUN mkdir -p nodejs/node22/
RUN cp -r node_modules nodejs/node22/
RUN zip -r lambda-sharp-layer.zip nodejs
