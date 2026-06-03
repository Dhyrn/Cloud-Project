###############################################################################
# Environment: dev
#
# Wires the 4 modules together:
#
#   vpc      → network skeleton (public/private subnets, IGW, RTs, db subnet group)
#   queue    → SQS standard + DLQ
#   compute  → EC2 host with web/app SGs and IAM instance profile
#   db       → RDS Postgres in private subnets, password in Secrets Manager
#
# Dependency order:
#   vpc has no deps
#   queue has no deps
#   compute depends on vpc + queue (for IAM scope)
#   db depends on vpc + compute (for app SG)
###############################################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# --- vpc ------------------------------------------------------------------ #

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  tags = local.common_tags
}

# --- queue ---------------------------------------------------------------- #

module "queue" {
  source = "../../modules/queue"

  name_prefix                  = local.name_prefix
  max_receive_count_before_dlq = var.sqs_max_receive_count

  tags = local.common_tags
}

# --- compute -------------------------------------------------------------- #

module "compute" {
  source = "../../modules/compute"

  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]

  instance_type = var.instance_type
  key_name      = var.key_name

  public_ingress_ports = var.public_ingress_ports
  allow_ssh            = var.allow_ssh
  ssh_allowed_cidrs    = var.ssh_allowed_cidrs

  enable_ssm_session_manager = true
  tags                       = local.common_tags
}

# --- IAM policies attached to the EC2 role (broken out of compute to ------ #
# avoid a circular dependency between compute and db) -------------------- #

data "aws_iam_policy_document" "ec2_sqs" {
  statement {
    sid    = "SQSProducer"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
    ]
    resources = [module.queue.product_events_queue_arn]
  }

  statement {
    sid    = "SQSConsumer"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [module.queue.product_events_queue_arn]
  }

  statement {
    sid    = "SQSDlqInspect"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [module.queue.product_events_dlq_arn]
  }
}

resource "aws_iam_role_policy" "ec2_sqs" {
  name   = "${local.name_prefix}-sqs-access"
  role   = module.compute.instance_role_name
  policy = data.aws_iam_policy_document.ec2_sqs.json
}

data "aws_iam_policy_document" "ec2_secrets" {
  statement {
    sid    = "ReadDbSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [module.db.secret_arn]
  }
}

resource "aws_iam_role_policy" "ec2_secrets" {
  name   = "${local.name_prefix}-secrets-read"
  role   = module.compute.instance_role_name
  policy = data.aws_iam_policy_document.ec2_secrets.json
}

# --- db ------------------------------------------------------------------- #

module "db" {
  source = "../../modules/db"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

  # RDS only accepts ingress from the app SG.
  app_security_group_id = module.compute.app_security_group_id

  engine_version  = var.db_engine_version
  instance_class  = var.db_instance_class
  database_name   = var.db_database_name
  master_username = var.db_master_username

  multi_az                = false # dev: single AZ
  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = local.common_tags
}
