###############################################################################
# Module: queue — SQS Standard + DLQ
#
# Originally from week9 (microservices-project/infra/week9-sqs/main.tf).
# Drop FIFO variant (Standard is sufficient for the product-events flow).
#
# Behavior:
#   - product_events: standard queue with long polling and DLQ redrive
#   - product_events_dlq: dead-letter queue, retains messages 14 days
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

resource "aws_sqs_queue" "product_events_dlq" {
  name                      = "${var.name_prefix}-product-events-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-product-events-dlq"
    Role = "dlq"
  })
}

resource "aws_sqs_queue" "product_events" {
  name                       = "${var.name_prefix}-product-events"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_events_dlq.arn
    maxReceiveCount     = var.max_receive_count_before_dlq
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-product-events"
    Role = "main"
  })
}
