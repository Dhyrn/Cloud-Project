variable "name_prefix" {
  description = "Prefix for all DB resources (e.g. cncloud-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the DB security group lives."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group (from the vpc module). RDS will be placed in these subnets."
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID of the application tier — Postgres ingress is opened ONLY from this SG."
  type        = string
}

# --- Engine + sizing -------------------------------------------------------- #

variable "engine_version" {
  description = "Postgres engine version. Use 'major' (e.g. '17') to let AWS pick the latest minor; or 'X.Y' to pin."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro is free-tier eligible."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max storage for storage autoscaling. Set to 0 to disable."
  type        = number
  default     = 50
}

# --- Logical DB ------------------------------------------------------------- #

variable "database_name" {
  description = "Initial database name created inside the instance."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master DB username."
  type        = string
  default     = "appadmin"
}

# --- Reliability + lifecycle ----------------------------------------------- #

variable "multi_az" {
  description = "Whether to deploy a standby in a second AZ. false in dev (cheaper)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to keep automated backups. 0 disables backups."
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is destroyed. true in dev so terraform destroy is fast."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block terraform destroy of the instance. Should be true in prod."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes immediately or wait for the next maintenance window."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
