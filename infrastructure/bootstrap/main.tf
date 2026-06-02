###############################################################################
# Bootstrap — one-shot Terraform stack to set up the AWS account.
#
# This is the ONLY Terraform configuration in the project with LOCAL state,
# because it CREATES the S3 bucket + DynamoDB table that all other Terraform
# stacks will use as their remote backend.
#
# It also creates:
#   - Billing alarms (SNS + email subscription + CloudWatch alarms)
#   - GitHub Actions OIDC identity provider + deployer IAM role
#
# After running this once successfully, commit the OUTPUTS (not the state)
# and tell other team members the names of the backend resources so they
# can configure their own Terraform stacks to use the remote backend.
#
# Run with:
#   cd infrastructure/bootstrap
#   cp terraform.tfvars.example terraform.tfvars
#   # edit terraform.tfvars
#   terraform init
#   terraform plan
#   terraform apply
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # NO backend block here. This bootstrap uses LOCAL state because it
  # creates the resources that the remote backend will use.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "bootstrap"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# Data sources used across the bootstrap
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Account-scoped bucket name (S3 bucket names are global; this avoids
  # collisions while still being deterministic per account+region).
  state_bucket_name = "${var.project_name}-tf-state-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  locks_table_name  = "${var.project_name}-tf-locks"
}
