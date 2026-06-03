###############################################################################
# Environment-level inputs.
# Common values live in terraform.tfvars (gitignored — copy from .example).
###############################################################################

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix used in resource names + tags."
  type        = string
  default     = "cncloud"
}

variable "environment" {
  description = "Environment name (used in name_prefix and tags)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Free-form team / owner tag value."
  type        = string
  default     = "team"
}

# --- VPC ------------------------------------------------------------------ #

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# --- Queue ---------------------------------------------------------------- #

variable "sqs_max_receive_count" {
  description = "Receives before a message moves to the DLQ."
  type        = number
  default     = 3
}

# --- Compute -------------------------------------------------------------- #

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair (e.g. week6-key)."
  type        = string
}

variable "public_ingress_ports" {
  description = "TCP ports open to the world on the web SG."
  type        = list(number)
  default     = [80, 8080]
}

variable "allow_ssh" {
  type    = bool
  default = true
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# --- DB ------------------------------------------------------------------- #

variable "db_engine_version" {
  description = "Postgres engine version. Use 'major' (e.g. '17') to let AWS pick the latest minor. Use 'X.Y' for a pinned minor."
  type        = string
  default     = "17"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_database_name" {
  type    = string
  default = "appdb"
}

variable "db_master_username" {
  type    = string
  default = "appadmin"
}
