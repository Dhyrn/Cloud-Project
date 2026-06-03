variable "name_prefix" {
  description = "Prefix applied to all queue names (e.g. cncloud-dev)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))
    error_message = "name_prefix must be lowercase, 3-31 chars, start with a letter."
  }
}

variable "max_receive_count_before_dlq" {
  description = "Number of receive attempts before a message moves to the DLQ."
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count_before_dlq >= 1 && var.max_receive_count_before_dlq <= 1000
    error_message = "max_receive_count_before_dlq must be between 1 and 1000."
  }
}

variable "visibility_timeout_seconds" {
  description = "How long a message is invisible after being received. Should be >= longest expected processing time."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "How long messages stay in the main queue before being deleted (max 1209600 = 14 days)."
  type        = number
  default     = 345600 # 4 days
}

variable "receive_wait_time_seconds" {
  description = "Long-polling wait time (0-20). 20 is recommended for cost and latency."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags applied to all queue resources."
  type        = map(string)
  default     = {}
}
