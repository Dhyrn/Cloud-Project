###############################################################################
# Module: db — RDS Postgres + AWS Secrets Manager for the password
#
# Based on week7 (terraform-week7/rds.tf) with key improvements:
#   - Password is RANDOMLY GENERATED here (random_password) and stored in
#     AWS Secrets Manager; NEVER taken from a tfvars.
#   - DB subnet group comes from the vpc module (not duplicated here).
#   - Security group accepts inbound only from the application SG, not from
#     a CIDR block.
#   - DB endpoint + secret ARN exposed as outputs so the compute module and
#     the application can consume them at runtime.
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
}

# ---------- Generated DB password ------------------------------------------- #

resource "random_password" "db" {
  length  = 24
  special = true
  # RDS Postgres disallows /, @, ", ' in master password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name_prefix}-db-credentials"
  description = "RDS master credentials for ${var.name_prefix}"
  # Quick destroy in dev. Bump to 7-30 days for prod.
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name
  })
}

# ---------- Security group -------------------------------------------------- #

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allows Postgres traffic from the application security group only"
  vpc_id      = var.vpc_id

  # Ingress is added below via an aws_security_group_rule so we can reference
  # the app SG by ID (cross-module input).

  egress {
    description = "Allow all egress (default for RDS - outbound traffic is limited by RDS anyway)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}

resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.app_security_group_id
  security_group_id        = aws_security_group.db.id
  description              = "Postgres from app SG"
}

# ---------- RDS instance ---------------------------------------------------- #

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.db.result

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  apply_immediately = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })

  lifecycle {
    # If you change the password manually in the console, Terraform will
    # show drift. Ignore password and let Secrets Manager be the source of
    # truth after rotation (manual or automated).
    ignore_changes = [password]
  }
}
