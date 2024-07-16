terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.58.0"
    }
  }

  cloud {
    organization = "lanchonete-do-bairro"

    workspaces {
      name = "lanchonete-do-bairro-workspace"
    }
  }
}