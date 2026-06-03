###############################################################################
# Environment outputs — what Ansible, the apps, and the team need to know.
###############################################################################

# --- VPC ------------------------------------------------------------------ #

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# --- Compute -------------------------------------------------------------- #

output "ec2_instance_id" {
  description = "EC2 instance ID — input for Ansible dynamic inventory tag filters."
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Public IPv4 of the application host."
  value       = module.compute.instance_public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the application host."
  value       = module.compute.instance_public_dns
}

output "ec2_instance_role_arn" {
  value = module.compute.instance_role_arn
}

# --- Queue ---------------------------------------------------------------- #

output "sqs_queue_url" {
  description = "URL of the product-events SQS queue (producer + consumer)."
  value       = module.queue.product_events_queue_url
}

output "sqs_queue_arn" {
  value = module.queue.product_events_queue_arn
}

output "sqs_dlq_url" {
  value = module.queue.product_events_dlq_url
}

# --- DB ------------------------------------------------------------------- #

output "db_endpoint" {
  description = "RDS endpoint (host:port). The Postgres password is in Secrets Manager."
  value       = module.db.db_instance_endpoint
}

output "db_address" {
  value = module.db.db_instance_address
}

output "db_name" {
  value = module.db.database_name
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding RDS credentials."
  value       = module.db.secret_arn
}

output "db_secret_name" {
  value = module.db.secret_name
}

# --- SSH connect hint ----------------------------------------------------- #

output "ssh_command" {
  description = "Copy-paste command to SSH into the EC2 host (requires the key PEM)."
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.compute.instance_public_ip}"
}
