###############################################################################
# Outputs — values to copy into other Terraform stacks and GitHub Actions.
###############################################################################

output "aws_account_id" {
  description = "AWS account ID this bootstrap runs in."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region the bootstrap was deployed to."
  value       = data.aws_region.current.name
}

###############################################################################
# Remote state backend — paste into other stacks' backend "s3" block.
###############################################################################

output "tf_state_bucket" {
  description = "S3 bucket name to use as the Terraform remote backend."
  value       = aws_s3_bucket.tf_state.id
}

output "tf_locks_table" {
  description = "DynamoDB table for Terraform state locking."
  value       = aws_dynamodb_table.tf_locks.id
}

output "backend_block_example" {
  description = "Drop-in backend block for other Terraform configurations."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.tf_state.id}"
        key            = "envs/dev/terraform.tfstate"
        region         = "${data.aws_region.current.name}"
        dynamodb_table = "${aws_dynamodb_table.tf_locks.id}"
        encrypt        = true
      }
    }
  EOT
}

###############################################################################
# Billing alarm
###############################################################################

output "billing_sns_topic_arn" {
  description = "SNS topic ARN that fans out billing alarms to your email."
  value       = aws_sns_topic.billing_alerts.arn
}

output "billing_warn_alarm_name" {
  description = "Name of the warn-level CloudWatch billing alarm."
  value       = aws_cloudwatch_metric_alarm.billing_warn.alarm_name
}

output "billing_critical_alarm_name" {
  description = "Name of the critical-level CloudWatch billing alarm."
  value       = aws_cloudwatch_metric_alarm.billing_critical.alarm_name
}

###############################################################################
# GitHub Actions OIDC — copy gha_deployer_role_arn into the repo's secrets
# as AWS_ROLE_TO_ASSUME.
###############################################################################

output "gha_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "gha_deployer_role_arn" {
  description = "ARN of the GitHub Actions deployer role. Set as repo secret AWS_ROLE_TO_ASSUME."
  value       = aws_iam_role.gha_deployer.arn
}

output "gha_deployer_role_name" {
  description = "Name of the GitHub Actions deployer role."
  value       = aws_iam_role.gha_deployer.name
}
