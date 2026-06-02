variable "aws_region" {
  description = "AWS region to deploy bootstrap resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name, used as a prefix on resource names. Lowercase, no spaces."
  type        = string
  default     = "cncloud"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project_name))
    error_message = "project_name must be 3-16 chars, lowercase, start with a letter, may include digits and hyphens."
  }
}

variable "owner" {
  description = "Free-form team / owner tag value (e.g. team-x, dhiren)."
  type        = string
  default     = "team"
}

###############################################################################
# Billing alarm
###############################################################################

variable "billing_email" {
  description = "Email address that receives billing-alert notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.billing_email))
    error_message = "billing_email must be a valid email address."
  }
}

variable "billing_warn_threshold_usd" {
  description = "Warn threshold (USD) for the soft billing alarm."
  type        = number
  default     = 5
}

variable "billing_critical_threshold_usd" {
  description = "Critical threshold (USD) for the hard billing alarm."
  type        = number
  default     = 20
}

###############################################################################
# GitHub Actions OIDC
###############################################################################

variable "github_org" {
  description = "GitHub user or organization that owns the repository (case-sensitive)."
  type        = string
}

variable "github_repo" {
  description = "Repository name (case-sensitive)."
  type        = string
}

variable "github_branch_filter" {
  description = "Branch pattern the role is allowed to be assumed from. Use '*' for any branch (dev convenience) or 'main' to lock to main only."
  type        = string
  default     = "*"
}
