#!/bin/bash
# **************************************************************************
# manually build the docker image and push it to the ECR repository
# **************************************************************************
# Note:
# Usually not needed, as terraform will build and push the docker image.

$(aws ecr get-login --no-include-email --region us-west-2)
docker build -t demoapp .
docker tag demoapp:latest $(terraform output repository_url):latest
docker push $(terraform output repository_url):latest