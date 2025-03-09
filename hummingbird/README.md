# Hummingbird

A simple REST API to upload media files for processing. This is an experiment, as such, some of the architectural
decisions may not be suitable for real production environments.

## Directory structure

- `app`: contains the Express.js application, which implements the API endpoints for media management.
- `lambdas`: contains the AWS Lambda's code. These lambdas support the asynchronous workflows, such as image processing
  and deletion.
- `docs`: contains documentation files for the app, including Dynamo DB table schema and OpenAPI scheme files.
