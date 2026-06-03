###############################################################################
# Remote state backend (created by infrastructure/bootstrap).
#
# Do NOT change these values without also updating any other stack that
# might be sharing the bucket/table.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "cncloud-tf-state-969831127354-us-east-1"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cncloud-tf-locks"
    encrypt        = true
  }
}
