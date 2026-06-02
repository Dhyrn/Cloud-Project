###############################################################################
# Remote Terraform state backend
#
#   S3 bucket  - stores terraform.tfstate (versioned, encrypted, private)
#   DynamoDB   - state-locking + consistency (LockID partition key)
###############################################################################

resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket_name

  # Refuse to be destroyed by accident — state loss is catastrophic.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = local.state_bucket_name
    Purpose = "terraform-remote-state"
  }
}

# Versioning ON — recover state on accidental corruption or deletion.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with AWS-managed keys (SSE-S3).
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block ALL public access at the bucket level.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking. Partition key MUST be named "LockID".
resource "aws_dynamodb_table" "tf_locks" {
  name         = local.locks_table_name
  billing_mode = "PAY_PER_REQUEST" # pennies for our workload, no capacity planning

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = local.locks_table_name
    Purpose = "terraform-state-lock"
  }
}
