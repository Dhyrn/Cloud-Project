output "instance_id" {
  description = "ID of the application EC2 instance."
  value       = aws_instance.main.id
}

output "instance_public_ip" {
  description = "Public IPv4 of the EC2 instance (where docker-compose runs)."
  value       = aws_instance.main.public_ip
}

output "instance_private_ip" {
  description = "Private IPv4 of the EC2 inside the VPC (used by RDS SG ingress)."
  value       = aws_instance.main.private_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance."
  value       = aws_instance.main.public_dns
}

# --- Security groups ----------------------------------------------------- #

output "web_security_group_id" {
  description = "ID of the web SG (open to the internet)."
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "ID of the app SG. Pass this as app_security_group_id to the db module."
  value       = aws_security_group.app.id
}

# --- IAM ------------------------------------------------------------------ #

output "instance_role_arn" {
  description = "ARN of the IAM role attached to the EC2."
  value       = aws_iam_role.ec2.arn
}

output "instance_role_name" {
  description = "Name of the IAM role attached to the EC2."
  value       = aws_iam_role.ec2.name
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile."
  value       = aws_iam_instance_profile.ec2.name
}
