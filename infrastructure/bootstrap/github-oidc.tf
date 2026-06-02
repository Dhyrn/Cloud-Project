###############################################################################
# GitHub Actions ↔ AWS via OIDC
#
# Instead of storing long-lived AWS access keys in GitHub Actions secrets,
# this provider lets the workflow exchange a short-lived GitHub OIDC token
# for an AWS STS session.
#
# What gets created:
#   - The OIDC identity provider for token.actions.githubusercontent.com
#     (only ONE per AWS account — if you re-run this in another account,
#      adopt the existing one with `terraform import`).
#   - An IAM role (gha-deployer) whose trust policy only accepts tokens
#     from the configured GitHub repository (+ branch filter).
#
# The role currently uses `PowerUserAccess` to make Day 1 productive.
# Before submission (task #13 — Security audit), tighten this to an inline
# policy listing only the actions the deploy workflow actually needs.
###############################################################################

# Fetches GitHub's current TLS cert so we don't have to hardcode thumbprints.
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# Trust policy: only tokens issued by GitHub for the specified repo can assume.
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    sid     = "GitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch_filter}",
        "repo:${var.github_org}/${var.github_repo}:pull_request",
        "repo:${var.github_org}/${var.github_repo}:environment:*",
      ]
    }
  }
}

resource "aws_iam_role" "gha_deployer" {
  name        = "${var.project_name}-gha-deployer"
  description = "Assumed by GitHub Actions in ${var.github_org}/${var.github_repo} to deploy infrastructure and applications."

  assume_role_policy   = data.aws_iam_policy_document.gha_assume_role.json
  max_session_duration = 3600
}

# Day 1: broad permissions to unblock CI/CD development.
# TODO (task #13 Security audit): replace with a custom inline policy that
# lists only the actions the workflows actually need.
resource "aws_iam_role_policy_attachment" "gha_deployer_poweruser" {
  role       = aws_iam_role.gha_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUserAccess does NOT include iam:* — give the role enough IAM perms
# to manage the application instance profile (and only that).
data "aws_iam_policy_document" "gha_deployer_iam_helper" {
  statement {
    sid    = "ManageAppInstanceProfileAndPassRole"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:ListInstanceProfilesForRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-*",
    ]
  }
}

resource "aws_iam_role_policy" "gha_deployer_iam_helper" {
  name   = "${var.project_name}-iam-helper"
  role   = aws_iam_role.gha_deployer.id
  policy = data.aws_iam_policy_document.gha_deployer_iam_helper.json
}
