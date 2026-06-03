output "product_events_queue_url" {
  description = "URL of the main product-events queue (producer + consumer use this)."
  value       = aws_sqs_queue.product_events.id
}

output "product_events_queue_arn" {
  description = "ARN of the main product-events queue (used by IAM policies)."
  value       = aws_sqs_queue.product_events.arn
}

output "product_events_queue_name" {
  description = "Name of the main product-events queue."
  value       = aws_sqs_queue.product_events.name
}

output "product_events_dlq_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.product_events_dlq.id
}

output "product_events_dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = aws_sqs_queue.product_events_dlq.arn
}
