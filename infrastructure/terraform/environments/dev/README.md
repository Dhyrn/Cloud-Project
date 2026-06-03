# environments/dev

The development environment wires the 4 modules (`vpc`, `queue`, `compute`,
`db`) into a single stack. State lives in the S3 bucket created by
`infrastructure/bootstrap`.

## Layout

```
environments/dev/
├── backend.tf                  # S3 + DynamoDB remote state
├── main.tf                     # provider + 4 module blocks + IAM glue policies
├── variables.tf                # all environment-level inputs
├── outputs.tf                  # what Ansible / apps need (RDS endpoint, EC2 IP, ...)
├── terraform.tfvars.example    # template, copy to terraform.tfvars
└── README.md                   # this file
```

## How to run

```bash
cd infrastructure/terraform/environments/dev

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars (most defaults are fine)

terraform fmt -check -diff
terraform init
terraform validate
terraform plan
terraform apply
```

Expected resources (≈22):

- VPC, IGW, 2 public + 2 private subnets, 2 RTs + associations, DB subnet group
- 1 EC2 t3.micro + 1 IAM role + 1 instance profile + SSM attachment
- 2 application SGs (web + app)
- RDS Postgres + DB SG + ingress rule
- Random password + Secrets Manager secret + secret version
- SQS standard + DLQ
- 2 inline IAM policies on the EC2 role (SQS + Secrets read)

## What is intentionally NOT in this stack

- **Backend setup** — that lives in `infrastructure/bootstrap` and is run once
  per account.
- **GitHub Actions OIDC** — also in bootstrap.
- **Application code / containers** — Ansible deploys those after this stack
  succeeds; the EC2 is pre-bootstrapped with Docker via user_data.

## Outputs you will care about

| Output | Used by |
|---|---|
| `ec2_public_ip` / `ec2_public_dns` | Ansible inventory + DNS docs |
| `ssh_command` | Manual SSH troubleshooting |
| `sqs_queue_url` / `sqs_queue_arn` | App env vars + IAM verification |
| `db_endpoint` / `db_name` | App connection string |
| `db_secret_arn` | App reads credentials at runtime |

## Teardown

```bash
terraform destroy
```

RDS deletion takes ~5 min. There is no final snapshot (dev), so destroy
returns the DB to nothing.
