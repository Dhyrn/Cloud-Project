###############################################################################
# Billing alarms
#
#   SNS topic + email subscription receive every notification.
#   Two CloudWatch alarms watch AWS/Billing EstimatedCharges:
#     - warn      (default $5)
#     - critical  (default $20)
#
# IMPORTANT — billing metrics are PUBLISHED ONLY in us-east-1, regardless of
# the region the account is using. The provider in main.tf is already us-east-1,
# so this works as-is. If you ever change var.aws_region, add an explicit
# aliased provider for us-east-1 here.
#
# The email subscription requires a one-time confirmation: SNS will send a
# "AWS Notification - Subscription Confirmation" email. Click the link inside
# or no alerts will reach you.
###############################################################################

resource "aws_sns_topic" "billing_alerts" {
  name = "${var.project_name}-billing-alerts"
}

resource "aws_sns_topic_subscription" "billing_email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.billing_email
}

resource "aws_cloudwatch_metric_alarm" "billing_warn" {
  alarm_name          = "${var.project_name}-billing-warn-${var.billing_warn_threshold_usd}usd"
  alarm_description   = "Estimated charges exceeded the WARN threshold of $${var.billing_warn_threshold_usd}."
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.billing_warn_threshold_usd
  evaluation_periods  = 1
  period              = 21600 # 6h — billing metric updates a few times a day
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.billing_alerts.arn]
  ok_actions    = [aws_sns_topic.billing_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "billing_critical" {
  alarm_name          = "${var.project_name}-billing-critical-${var.billing_critical_threshold_usd}usd"
  alarm_description   = "Estimated charges exceeded the CRITICAL threshold of $${var.billing_critical_threshold_usd}. Run terraform destroy."
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.billing_critical_threshold_usd
  evaluation_periods  = 1
  period              = 21600
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.billing_alerts.arn]
  ok_actions    = [aws_sns_topic.billing_alerts.arn]
}
