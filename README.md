# Project: aws-kubectl-tf-practice

## Description
This project is a practice repository for working with AWS, Kubernetes, and Terraform.

## Files

- `README.md`: This file contains the project description and documentation.
- `main.tf`: This file contains the main Terraform configuration for provisioning AWS resources.
- `deployment.yaml`: This file contains the Kubernetes deployment configuration.
- `scripts/`: This directory contains various scripts used in the project.
- `demo/`: Minimal Spring Boot java application a la "Hello World!"


## Requirements
- `aws cli`: A configured version of AWS client with valid credentials in ~/.aws/credentials
- `terraform`: Hashicorp Terraform installed on the command line
- `kubectl`: Kubernetes commandline tool
- `docker`: a valid docker environment to create and run docker images
- `openjdk-17`: ideally as well an openjdk 17 installation, though this is now fetched as docker image

## Usage

1. Clone the repository: `git clone https://github.com/your-username/aws-kubectl-tf-practice.git`
2. Navigate to the project directory: `cd aws-kubectl-tf-practice`
3. update in variables.tf in the "aws_profile" section the value of default to the AWS account id of your credentials.
4. terraform does all the work: just run

```
terraform init
terraform apply
./portforward.sh
```
This will take about 30min and once it's done, it will open a web browser to the port
forwarded from the EKS cluster via kubectl.

5. Once you are done, you can tear the installation down via
```
export OLD_EKS_CLUSTER=$(terraform output -raw cluster_name)
teraform destroy
kubectl config delete-context $OLD_EKS_CLUSTER
```
Note: the kubectl is just to not have too many old contexts piling up in ~/.kube/config 

## Contributing
If you would like to contribute to this project, please follow the guidelines in the `CONTRIBUTING.md` file.

## License
This project is licensed under the [MIT License](LICENSE).