###############################################################################
# IAM instance profile for the application EC2
#
# This module ONLY creates the role + instance profile (and optionally
# attaches the SSM managed policy). The SQS and Secrets Manager policies
# are attached at the environment level (environments/dev/main.tf) so that
# we avoid a circular module dependency between compute and db.
#
# Trust: EC2 service.
# Permissions added here:
#   - Optional: AmazonSSMManagedInstanceCore (Session Manager shell)
# Permissions attached by the environment:
#   - SQS producer + consumer on the project queue
#   - secretsmanager:GetSecretValue on the DB credentials secret
###############################################################################

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  description        = "Assumed by EC2 instances in ${var.name_prefix} to access SQS + Secrets Manager"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = var.tags
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

# Optional Session Manager support — handy to shell in without SSH.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.enable_ssm_session_manager ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
