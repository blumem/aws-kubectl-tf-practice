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
```
aws configure
```

- `terraform`: Hashicorp Terraform installed on the command line
- `kubectl`: Kubernetes commandline tool
- `docker`: a valid docker environment to create and run docker images
- `openjdk-17`: ideally as well an openjdk 17 installation, though this is now fetched as docker image

## Usage

1. Clone the repository: `git clone https://github.com/your-username/aws-kubectl-tf-practice.git`
2. Navigate to the project directory: `cd aws-kubectl-tf-practice`
3. update in variables.tf 
    1. in the "aws_profile" section the value of default to the AWS account id of your credentials.
    2. in the "aws_region" section the region like us-weast-1
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

## Manual steps
If terraform get's stuck or you want to understand the steps it performs automagically for you,
please see below:

```
$ export AWS_ACCOUNT_ID=<your-16-digit-userid-configured in .aws/credentials>
$ export AWS_REGION=<your region>
$ docker buildx build . -t demoapp:latest
$ aws ecr create-repository -region $AWS_REGION –regsitry-name demoapp-ecr
$ aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/demoapp-ecr
$ docker tag demoapp:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/demoapp-ecr:demoapp
$ docker push demoapp:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/demoapp-ecr:demoapp
$ eksctl create cluster --name demoapp-cluster --region $AWS_REGION --node-type t2.micro --nodes 3
$ aws eks --region $AWS_REGION update-kubeconfig --name demoapp-cluster
$ kubectl apply -f deployment.yaml
$ kubectl port-forward deployment/demoapp-deployment 8089:8080 
```

Now you can visit http://localhost:8089 and play with the spring boot servlet. 

To revert, press CTRL-C to stop kubectl portforwarding.

```
$ kubectl delete -f deployment.yaml
$ eksctl delete cluster --name demoapp-cluster --region $AWS_REGION 
$ ./teardown.sh
$ aws ecr delete-repository -region $AWS_REGION –regsitry-name demoapp-ecr

```
Note: ./teardown.sh delete all images in the AWS ECR (Registry)

## Contributing
If you would like to contribute to this project, please follow the guidelines in the `CONTRIBUTING.md` file.

## License
This project is licensed under the [MIT License](LICENSE).