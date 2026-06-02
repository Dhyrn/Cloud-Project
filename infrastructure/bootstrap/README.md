# Bootstrap

> One-shot Terraform stack that prepares the AWS account before any other
> Terraform configuration is applied. **Runs once per account.**

## What it creates

| Resource | Purpose |
|---|---|
| S3 bucket `cncloud-tf-state-<ACCOUNT_ID>-<REGION>` | Remote Terraform state for every other stack (versioning, encryption, public access blocked). |
| DynamoDB table `cncloud-tf-locks` | Terraform state locking (PAY_PER_REQUEST, partition key `LockID`). |
| SNS topic `cncloud-billing-alerts` + email subscription | Sends billing alarms to the configured email. |
| CloudWatch alarms `cncloud-billing-warn-5usd`, `cncloud-billing-critical-20usd` | Trigger when estimated charges exceed $5 / $20. |
| IAM OIDC provider for `token.actions.githubusercontent.com` | Lets GitHub Actions exchange OIDC tokens for AWS sessions (no static keys). |
| IAM role `cncloud-gha-deployer` | Assumed by workflows in `Dhyrn/Cloud-Project` to deploy infrastructure and applications. Currently has `PowerUserAccess` — tighten before submission. |

## Why is this stack special

This is the **only** Terraform configuration in the project with **local
state**, because it creates the S3 bucket + DynamoDB table that every
other stack uses as their remote backend.

After running once, the local `terraform.tfstate` lives in this directory
and is `.gitignore`d. Other team members do **not** re-run this; they just
use the resources that the first run created.

## How to run (once per account)

1. Make sure your AWS CLI is configured with credentials that have admin
   rights (the very first run needs to create IAM resources).

   ```bash
   aws sts get-caller-identity
   ```

2. Copy the example tfvars and edit it:

   ```bash
   cd infrastructure/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars and fill in real values
   ```

3. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Confirm the SNS subscription**: AWS will send a "Subscription
   Confirmation" email to `billing_email`. Click the link inside.
   Without confirming, you will not receive any alarm notifications.

5. Copy the outputs you need:

   ```bash
   terraform output -raw tf_state_bucket
   terraform output -raw tf_locks_table
   terraform output -raw gha_deployer_role_arn
   ```

6. Add `gha_deployer_role_arn` as the GitHub repository secret
   `AWS_ROLE_TO_ASSUME` (Settings → Secrets and variables → Actions).

## After bootstrap — wiring up other stacks

Use the `backend_block_example` output verbatim in any other Terraform
stack's root module:

```hcl
terraform {
  backend "s3" {
    bucket         = "cncloud-tf-state-<ACCOUNT_ID>-us-east-1"
    key            = "envs/dev/terraform.tfstate"   # change per environment
    region         = "us-east-1"
    dynamodb_table = "cncloud-tf-locks"
    encrypt        = true
  }
}
```

## When NOT to re-run

- A new team member joins → they do NOT re-run bootstrap. They configure
  AWS CLI with their own credentials and just point their other Terraform
  stacks at the same S3 bucket.

- You change the project name, region, or want a clean slate → first
  `terraform destroy` carefully (the S3 bucket has `prevent_destroy =
  true` so you'll need to remove that flag first). Then re-run.

## Cost

All resources here are essentially free under normal usage:

- S3 state bucket: < $0.01/month
- DynamoDB PAY_PER_REQUEST: < $0.01/month for tf locks
- SNS + CloudWatch billing alarm: free
- IAM resources: free
