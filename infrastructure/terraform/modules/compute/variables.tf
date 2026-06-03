variable "name_prefix" {
  description = "Prefix for all compute resources (e.g. cncloud-dev)."
  type        = string
}

# --- Network -------------------------------------------------------------- #

variable "vpc_id" {
  description = "VPC ID from the vpc module."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID to place the EC2 in."
  type        = string
}

# --- Instance ------------------------------------------------------------- #

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing EC2 key pair (e.g. week6-key)."
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 16
}

# --- Networking access ---------------------------------------------------- #

variable "public_ingress_ports" {
  description = "TCP ports opened to the world on the web SG (e.g. [80, 8080] for the API gateway)."
  type        = list(number)
  default     = [80, 8080]
}

variable "allow_ssh" {
  description = "Whether to open port 22 on the web SG. Disable in prod and use SSM Session Manager."
  type        = bool
  default     = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH. Default is fully open; restrict to your IP in real use."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- IAM ------------------------------------------------------------------ #
#
# The SQS and Secrets Manager policies are attached to this role at the
# environment level (environments/dev/main.tf), to avoid a circular
# dependency between the compute and db modules.

variable "enable_ssm_session_manager" {
  description = "Attach AmazonSSMManagedInstanceCore so you can shell in via SSM."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
