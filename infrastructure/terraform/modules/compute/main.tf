###############################################################################
# Module: compute — EC2 host(s) running the containerised services
#
# Based on week6 launch-ec2.sh + week7 main.tf + week8 modules/ec2/main.tf,
# with the following changes:
#   - Separates web SG (public ports) from app SG (consumed by db module to
#     allow Postgres ingress) — even with a single EC2, this lets us prove
#     proper tiered security on the defense.
#   - user_data bootstrap installs Docker + docker-compose so the box is
#     ready for Ansible to drop in the containers.
#   - Attaches an IAM instance profile (defined in iam.tf) so the running
#     containers can call SQS and read DB credentials from Secrets Manager
#     WITHOUT environment-injected access keys.
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Latest Amazon Linux 2 (matches week6/7 labs, has Python preinstalled
# for Ansible without any bootstrap raw module).
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- Web SG (public ingress from internet) ---------------------------------- #

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Public ingress for the API gateway / public endpoints"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.public_ingress_ports
    content {
      description = "Public ingress on TCP/${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # SSH (optional — restrict to admin IP in prod; 0.0.0.0/0 in dev is fine
  # because access also requires the SSH key pair).
  dynamic "ingress" {
    for_each = var.allow_ssh ? [22] : []
    content {
      description = "SSH (week6-key required)"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    description = "All outbound (pull images, AWS API)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-web-sg"
    Tier = "web"
  })
}

# --- App SG (used by the db module to gate Postgres ingress) ---------------- #
#
# We attach BOTH the web and app SGs to the single EC2 host. The db SG only
# accepts traffic from the app SG, so any container running on this host can
# reach Postgres without exposing it to the internet.

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "App-tier SG. RDS only allows ingress from this SG."
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-sg"
    Tier = "app"
  })
}

# --- Bootstrap script ------------------------------------------------------- #
# Installs Docker + docker-compose plugin. Ansible runs afterwards to deploy
# the actual containers — we just make sure the host is ready.

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    yum update -y
    amazon-linux-extras install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    # docker-compose v2 plugin
    DOCKER_CONFIG=$${DOCKER_CONFIG:-/usr/local/lib/docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
      -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
  EOT
}

# --- EC2 instance ----------------------------------------------------------- #

resource "aws_instance" "main" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id

  vpc_security_group_ids = [
    aws_security_group.web.id,
    aws_security_group.app.id,
  ]

  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data            = local.user_data

  # If user_data changes, recreate the instance (otherwise Ansible would
  # already have changed the box and we don't want surprises).
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-host"
  })
}
