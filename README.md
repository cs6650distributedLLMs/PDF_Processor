# cs7990-master-thesis

Monorepo for all code created during the development of my Computer Sciences master thesis.

# Humming Architecture Diagram

![An architecture diagram depicting the AWS services used in the Hummingbird application.](images/hummingbird-architecture-diagram.png)

# Requirements

## Docker

This project utilizes Docker images to build resources, including Docker images for the ECS-powered app, and building an AWS Lambda layer for the Javascript sharp module.

Ensure that Docker is installed before running the Terraform plan/apply commands.

Follow the [official instructions to get Docker installed.](https://docs.docker.com/engine/install/)

## LocalStack CLI

The quickest way get started with LocalStack is by using the LocalStack CLI. It allows you to start LocalStack from your command line. Please make sure that you have a working Docker installation on your machine before moving on.

Follow the [official LocalStack docs](https://docs.localstack.cloud/getting-started/installation/) to install the CLI.

## awslocal CLI

This package provides the awslocal command, which is a thin wrapper around the aws command line interface for use with LocalStack.

Follow the installation guide [here](https://github.com/localstack/awscli-local?tab=readme-ov-file#installation).

## Terraform

Follow the [official Terraform docs](https://developer.hashicorp.com/terraform/install).

Make sure to install the latest version, or any version above v1.10.5.

## tflocal (Terraform) wrapper

`tflocal` is a small wrapper script to run Terraform against LocalStack. `tflocal` script uses the Terraform Override mechanism and creates a temporary file localstack_providers_override.tf to configure the endpoints for the AWS provider section. The endpoints for all services are configured to point to the LocalStack API (http://localhost:4566 by default). It allows you to easily deploy your unmodified Terraform scripts against LocalStack.

To install the tflocal command, you can use pip (assuming you have a local Python installation):

```shell
pip install terraform-local
```

# Getting Started

## Running on Localhost

The project is configured to run locally by using a single command. The automation is provided by the [Makefile](./Makefile).

To start the LocalStack CLI, deploy the infrastructure with Terraform and tail the logs, run:

```sh
make run-all-local
```

Once the deployment is done, you can access the API at: `http://hummingbird-alb.elb.localhost.localstack.cloud:4566`.
