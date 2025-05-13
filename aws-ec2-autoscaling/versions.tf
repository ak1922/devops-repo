terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.47.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.project_tags
  }
}
