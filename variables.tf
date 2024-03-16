variable "aws_profile" {
    description = "AWS profile to use"
    type        = string
    default     = "636480284744"
}

variable "docker_iamge_name" {
    description = "Name of the Docker image to build and push to ECR"
    type        = string
    default     = "demoapp"
}

variable "aws_region" {
    description = "AWS region"
    type        = string
    default     = "eu-central-1"
}

variable "ecr_repository_name" {
    description = "AWS ECR repository name"
    type        = string
    default     = "demoapp-ecr"
}