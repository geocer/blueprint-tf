terraform {
  required_version = ">= 1.0.0" # Defina a versão mínima do Terraform CLI

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Defina a versão mínima e máxima compatível do provedor AWS
    }
  }
}