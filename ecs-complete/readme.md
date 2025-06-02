openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout private.key -out certificate.crt


# AWS ECS Fargate Dynamic Infrastructure with Terraform

This repository contains Terraform code to deploy a scalable and flexible application infrastructure on AWS using ECS Fargate, managed by an Application Load Balancer (ALB). The setup is designed to be highly configurable, allowing for dynamic service definitions, listener rules, and fine-grained IAM permissions for ECS tasks.

---

## Table of Contents

1.  [Overview](#overview)
2.  [Core Components](#core-components)
3.  [Key Features & Requirements Implemented](#key-features--requirements-implemented)
    * [Dynamic ECS Service Deployment](#dynamic-ecs-service-deployment)
    * [Flexible ALB Listener Configurations](#flexible-alb-listener-configurations)
    * [Self-Signed SSL Certificate Import](#self-signed-ssl-certificate-import)
    * [ALB Deletion Protection & Internal/External Configuration](#alb-deletion-protection--internalexternal-configuration)
    * [Custom ECS Task Role Policies](#custom-ecs-task-role-policies)
4.  [Prerequisites](#prerequisites)
5.  [Configuration](#configuration)
6.  [Deployment](#deployment)
7.  [Cleanup](#cleanup)

---

## Overview

This Terraform project provisions a robust AWS infrastructure for containerized applications, including:
* An **ECS Fargate Cluster** to host your services.
* **Application Load Balancers (ALB)** for traffic distribution.
* **ECS Services** with auto-scaling capabilities.
* **Target Groups** dynamically configured for each service.
* **IAM Roles** for ECS tasks with extensible permissions.
* **Security Groups** to control network access.
* **CloudWatch Log Groups** for centralized logging.

The configuration is driven by a single `tfvars.auto.json` file, making it easy to define multiple services and their respective settings without modifying the core Terraform logic.

---

## Core Components

* **`main.tf`**: Defines the AWS resources, including the ECS cluster module, ALB module, and manual `aws_lb_target_group` and `aws_lb_listener` resources for granular control.
* **`variables.tf`**: Declares input variables for the project, allowing external configuration via `tfvars.auto.json`.
* **`locals.tf`**: Processes input variables, flattens data structures, and prepares configurations for resource creation, enhancing reusability and readability.
* **`tfvars.auto.json`**: The primary configuration file where you define project-specific values, ECS services, and their properties.

---

## Key Features & Requirements Implemented

This project addresses several specific requirements to provide a highly flexible and production-ready (for dev/test environments) setup:

### Dynamic ECS Service Deployment
The infrastructure supports defining multiple ECS Fargate services from a single input map (`ecs_services` in `tfvars.auto.json`). Each service can specify its:
* CPU and Memory.
* Container definitions (image, port mappings, essential flag, environment variables).
* Health check paths and ports.
* Desired count, minimum healthy percentage, and maximum percentage for deployments.
* Associated ALB listener ports and protocols.

### Flexible ALB Listener Configurations
The `aws_lb_listener` resources are dynamically created based on the `ecs_services` input. They support:
* **HTTPS and HTTP listeners**: Configurable per service.
* **`forward` actions**: To direct traffic to the respective ECS service's Target Group.
* **`fixed-response` default actions**: To provide a fallback or informational response for unhandled HTTP requests (e.g., on port 80).
* **Dynamic creation of multiple listeners per ALB**: Each service can implicitly define listeners for its associated ALB.

### Self-Signed SSL Certificate Import
A key requirement was to enable HTTPS listeners by allowing the import of a **self-signed SSL certificate** into AWS Certificate Manager (ACM). This is crucial for development and testing environments where a CA-signed certificate might not be immediately available.
* The `alb_certificate_arn` variable in `tfvars.auto.json` expects the ARN of a certificate imported into ACM.
* Instructions for generating and importing a self-signed certificate using OpenSSL are provided separately (in the chat history).

### ALB Deletion Protection & Internal/External Configuration
The Application Load Balancers are configured with:
* `enable_deletion_protection = false`: For easier cleanup in development environments. In production, this should typically be `true`.
* `internal = false`: The ALBs are public-facing by default, accessible from the internet. If an internal-only ALB is required, this value can be set to `true`.

### Custom ECS Task Role Policies
The ECS Task Execution Role (which allows Fargate tasks to pull images and publish logs) and the ECS Task Role (which the container application itself assumes) can be extended.
* Each ECS service definition in `tfvars.auto.json` now includes an `additional_task_role_policy_arns` field.
* You can provide a **list of ARNs of existing IAM policies** (both AWS managed and custom policies) to be attached to the respective ECS Task Role. This allows for granular control over the permissions your application needs (e.g., S3 access, DynamoDB access, etc.).

---

## Prerequisites

* **Terraform CLI** installed (v1.0.0 or higher recommended).
* **AWS CLI** configured with appropriate credentials and default region.
* **OpenSSL** installed (if generating self-signed certificates).
* A **VPC** with at least two **public subnets** and two **private subnets** in your target AWS region.
* An **S3 bucket** for ALB access logs.

---

## Configuration

1.  **Clone this repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Edit `variables.tf`**: Ensure the variable definitions match the expected structure, especially for `ecs_services` to include `additional_task_role_policy_arns`.

3.  **Edit `tfvars.auto.json`**:
    * Update `vpc_id`, `private_subnet_ids`, `public_subnet_ids` with your actual VPC and subnet IDs.
    * Set `alb_access_logs_bucket` to the name of your S3 bucket for ALB logs.
    * If using HTTPS, update `alb_certificate_arn` with the ARN of your ACM certificate. For self-signed certificates, generate and import them into ACM first.
    * Define your ECS services under `ecs_services`, customizing `cpu`, `memory`, `container_definitions`, `health_check_path`, `alb_listener_port`, `alb_protocol`, `alb_host_header`, and crucially, `additional_task_role_policy_arns`.

    **Example `tfvars.auto.json` snippet for `ecs_services`:**
    ```json
    {
      "ecs_services": {
        "frontend-app": {
          "cpu": 1024,
          "memory": 2048,
          "container_definitions": {
            "app": {
              "image": "public.ecr.aws/ecs-sample-app:latest",
              "container_port": 80
            }
          },
          "health_check_path": "/",
          "health_check_port": "traffic-port",
          "desired_count": 2,
          "min_healthy_percent": 50,
          "max_percent": 200,
          "alb_listener_port": 443,
          "alb_protocol": "HTTPS",
          "alb_host_header": "frontend.example.com",
          "additional_task_role_policy_arns": [
            "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
          ]
        },
        "backend-api": {
          "cpu": 512,
          "memory": 1024,
          "container_definitions": {
            "api": {
              "image": "[my-account-id.dkr.ecr.us-east-1.amazonaws.com/my-backend-api:v1.0](https://my-account-id.dkr.ecr.us-east-1.amazonaws.com/my-backend-api:v1.0)",
              "container_port": 3000
            }
          },
          "health_check_path": "/health",
          "health_check_port": "traffic-port",
          "desired_count": 1,
          "min_healthy_percent": 100,
          "max_percent": 400,
          "alb_listener_port": 443,
          "alb_protocol": "HTTPS",
          "alb_host_header": "api.example.com",
          "additional_task_role_policy_arns": []
        }
      }
    }
    ```

---

## Deployment

1.  **Initialize Terraform**:
    ```bash
    terraform init -upgrade
    ```

2.  **Review the plan**:
    ```bash
    terraform plan
    ```
    Carefully review the proposed changes.

3.  **Apply the changes**:
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm the deployment.

---

## Cleanup

To destroy all deployed resources:

```bash
terraform destroy



1. Gerar um arquivos de input tfvars.auto.json de forma que todos os servicos ecs fargate e suas caracteristicas sejam declarados nele 



2. para cada servico ecs fargate seja criado um target group e esse seja associado automaticamente a um alb, cada servico deve ser o seu proprio alb 



3. cada servico tera um security group respectivo 



4. Sejam usados exclusivamente os modulos remotos da comunidade aws sendo os exemplos abaixo



source = "terraform-aws-modules/ecs/aws" e source = "terraform-aws-modules/alb/aws"



5. Toda a logica para criacao dos recursos e parse do arquivo de input json seja colocada no arquivo locals.tf para os modulos ficarem limpos e com uma facil visualizacao


Para macOS: brew install buildpacks/pack/pack
Para Linux: curl -sSL https://github.com/buildpacks/pack/releases/download/v0.32.0/pack-v0.32.0-linux.tgz | sudo tar -C /usr/local/bin -xz pack

export AWS_REGION="us-east-1" # Sua região AWS
export REPOSITORY_NAME="sample-repo" # Nome do seu repositório ECR
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) # Pega seu ID da conta AWS
export ECR_REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
export IMAGE_TAG="latest" # Tag da sua imagem
export APP_SOURCE_PATH="." # Onde está o código-fonte do seu aplicativo ('.' para o diretório atual)

aws ecr create-repository \
  --repository-name "${REPOSITORY_NAME}" \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "${AWS_REGION}"

aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"


pack build "${ECR_REPO_URI}:${IMAGE_TAG}" \
  --path "${APP_SOURCE_PATH}" \
  --builder "paketobuildpacks/builder-jammy-base:latest" \
  --publish \
  --pull-policy if-not-present