output "db_instance_address" {
  description = "Hostname of the RDS instance (no port)."
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "Full RDS endpoint (host:port)."
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.main.port
}

output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.main.arn
}

output "db_instance_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.main.identifier
}

output "database_name" {
  description = "Logical database name created inside the instance."
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master DB username (the password is in Secrets Manager)."
  value       = aws_db_instance.main.username
}

output "security_group_id" {
  description = "ID of the DB security group."
  value       = aws_security_group.db.id
}

# Secrets Manager — applications and Ansible should read from here at runtime.

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding RDS credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.db.name
}
