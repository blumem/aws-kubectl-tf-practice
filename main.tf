# main.tf
provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  # load_config_file       = false
}
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}




# Step 1: create the AWS ECR registry
resource "aws_ecr_repository" "demoapp" {
  name = var.ecr_repository_name

  # let's make images more secure
  image_scanning_configuration {
    scan_on_push = true  
  } 
  image_tag_mutability = "MUTABLE"
  # TODO(mblume): regularly check-in below issue
  # https://github.com/hashicorp/terraform-provider-aws/issues/33523
  force_delete = true 
  # TODO(mblume): remove this once the issue is fixed
  # https://github.com/hashicorp/terraform-provider-aws/issues/33523
  # manually delete all images in the ECR repository on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "./teardown.sh"
  }
}



# ensure old images are deleted automatically to save space and cost
# from https://registry.terraform.io/providers/hashicorp/aws/2.33.0/docs/resources/ecr_lifecycle_policy
resource "aws_ecr_lifecycle_policy" "foopolicy" {
  repository = "${aws_ecr_repository.demoapp.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# Step 2: build and upload docker image to ECR
# Terraform itself does not directly support building or pushing Docker images. 
# It is designed to manage infrastructure, not to build or push Docker images. 
# However, you can use a null_resource with a local-exec provisioner to run shell commands.
resource "null_resource" "push_docker_image" {
  depends_on = [aws_ecr_repository.demoapp]

  provisioner "local-exec" {
    command = <<EOF
    $(aws ecr get-login --no-include-email --region ${var.aws_region})
    docker build -t ${var.docker_iamge_name} .
    docker tag ${var.docker_iamge_name}:latest ${aws_ecr_repository.demoapp.repository_url}:${var.docker_iamge_name}
    docker push ${aws_ecr_repository.demoapp.repository_url}:${var.docker_iamge_name}
    EOF
  }
}


# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "consor-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "consor-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  # IIRC, there should not be a public subnets in the past
  # public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # public_subnet_tags = {
  #   "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  #   "kubernetes.io/role/elb"                      = 1
  # }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}


# once created the EKS cluster, we need to configure kubectl
# to connect to it
# aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)

resource "null_resource" "configure_kubectl" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    when = create
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
  }
  # provisioner "local-exec" {
  #   when    = destroy
  #   command = "kubectl config delete-context ${module.eks.cluster_name}"
  # }
}

resource "kubernetes_deployment_v1" "java" {
  depends_on = [null_resource.configure_kubectl]
  
  metadata {
    name = "demoapp-deployment"
    labels = {
      app  = "demoapp"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app  = "demoapp"
      }
    }
    template {
      metadata {
        labels = {
          app  = "demoapp"
        }
      }
      spec {
        
        container {
          image = "${aws_ecr_repository.demoapp.repository_url}:${var.docker_iamge_name}"
          name  = "demoapp-container"          
          port {
            container_port = 8080
         }
        }
      }
    }
  }
}

resource "kubernetes_service" "java" {
  depends_on = [kubernetes_deployment_v1.java]
  metadata {
    name = "demoapp-service"
  }
  spec {
    selector = {
      app = "demoapp"
    }
    port {
      port        = 8081
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}

# Usueful commands once terraform is complete:
# Inspect nodes
#    kubectl get nodes -o custom-columns=Name:.metadata.name
# run image on port 80
#    kubectl run --port 80 --image ${aws_ecr_repository.demoapp.repository_url}:latest consor-demoapp
# Inspect list of pods:
#    kubectl get pods
#NAME                                  READY   STATUS    RESTARTS   AGE
#demoapp-deployment-76b8bcc995-5twqp   1/1     Running   0          6m39s
#demoapp-deployment-76b8bcc995-vbsdv   1/1     Running   0          6m39s
# port forward to the pod via kubectl so you can reach it from localhost:8089
#     kubectl port-forward deployment/demoapp-deployment 8089:8080
