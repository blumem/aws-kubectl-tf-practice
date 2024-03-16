#/bin/sh

# Script to delete all images of a given ECR repository

# TODO(mblume): remove script once terraform bug is fixed (see TODO in main.tf)

export ECR_REPOSITORY="$(terraform output -raw ecr_repository_name)"
export ECR_REGION="$(terraform output -raw region)"

echo "Deleting all images in ECR repository: $ECR_REPOSITORY in region: $ECR_REGION"
aws ecr batch-delete-image \
    --region $ECR_REGION \
    --repository-name $ECR_REPOSITORY \
    --image-ids "$(aws ecr list-images --region $ECR_REGION --repository-name $ECR_REPOSITORY --query 'imageIds[*]' --output json
)" || true