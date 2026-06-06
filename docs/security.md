# Security model

Where credentials live, how the application gets them, what permissions
each component has, and why.

## Principles applied

1. **No long-lived credentials anywhere** — neither in source, nor in
   container env files, nor in CI runner variables. Everything is either
   short-lived (OIDC tokens, IAM instance metadata) or sourced from AWS
   Secrets Manager at runtime.
2. **Least privilege** — every role has the minimum scope that lets it do
   its job. The application can publish to one queue and read one secret;
   it cannot list other queues or read other secrets.
3. **Network isolation** — the database lives in private subnets that have
   no internet egress at all. Inbound traffic to it is gated on a
   security-group reference, not a CIDR.

## Credential flows

### Developer → AWS (Terraform, Ansible from local)

```text
your IAM user (with MFA)
        │ ~/.aws/credentials (or AWS SSO session)
        ▼
   aws cli ──► STS ──► Terraform / Ansible
```

The Terraform CLI and Ansible's `aws secretsmanager get-secret-value` task
both use whatever credentials your local AWS CLI is configured with. You
never copy a long-lived secret into the repo.

### GitHub Actions → AWS (CI/CD)

```text
GitHub Actions runner
        │
        │ requests an OIDC token from GitHub
        ▼
sts:AssumeRoleWithWebIdentity   <── trust policy filters by repo + branch
        │
        ▼
short-lived AWS session (1 hour max) ──► Terraform / Ansible / AWS CLI
```

No AWS access keys in GitHub. The trust policy on `cncloud-gha-deployer`
restricts which repository, which `ref`, and which `aud` may assume the
role. See `infrastructure/bootstrap/github-oidc.tf`.

### EC2 → AWS (application reading the DB password)

```text
EC2 instance (cncloud-dev-app-host)
        │  has IAM instance profile cncloud-dev-ec2-profile
        │  metadata service IMDSv2 returns short-lived credentials
        ▼
container env (no AWS keys, no static config)
        │
        │  application reads ${DB_PASSWORD} from env, which Ansible
        │  populated at deploy time from Secrets Manager
        ▼
Spring Boot → JDBC → RDS
```

The EC2 role gives the application:
- `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage` on the one
  product-events queue.
- `secretsmanager:GetSecretValue` on the one DB credentials secret.
- `ssm:*` for Session Manager (optional, lets us shell in without
  exposing port 22 in prod).

That's it. The role cannot list other queues, cannot read other secrets,
cannot create resources.

## IAM resources at a glance

| Resource | Created by | Trusted principal | What it can do |
|---|---|---|---|
| `cncloud-gha-deployer` | `bootstrap` | GitHub OIDC, scoped to `Dhyrn/Cloud-Project:*` | `PowerUserAccess` + `iam:*` only on `cncloud-*` resources. **Tighten before submission.** |
| `cncloud-dev-ec2-role` (+ instance profile) | `terraform/modules/compute` | `ec2.amazonaws.com` | SQS on the project queue, Secrets Manager on the DB secret, SSM core |
| OIDC identity provider | `bootstrap` | — | One per account, referenced by trust policies |

The OIDC trust condition (in `bootstrap/github-oidc.tf`) checks:

```hcl
StringLike: token.actions.githubusercontent.com:sub  in
  - "repo:Dhyrn/Cloud-Project:ref:refs/heads/*"
  - "repo:Dhyrn/Cloud-Project:pull_request"
  - "repo:Dhyrn/Cloud-Project:environment:*"
StringEquals: token.actions.githubusercontent.com:aud == sts.amazonaws.com
```

Forks, other repositories, or branches outside this repo cannot assume
this role — even if a workflow yaml file leaks publicly.

## Secrets at rest

| Secret | Storage | Format | Rotation |
|---|---|---|---|
| RDS master password | AWS Secrets Manager (`cncloud-dev-db-credentials`) | JSON `{username, password, host, port, dbname, engine}` | Manual today; Secrets Manager rotation is supported but not configured. |
| GitHub Actions Docker Hub PAT | GitHub repo secret `DOCKERHUB_TOKEN` | string | Manual; revoke + recreate in Docker Hub UI. |
| SSH key for Ansible (`week6-key`) | GitHub repo secret `SSH_PRIVATE_KEY` + local `~/.ssh/week6-key.pem` | PEM | Manual; rotate by creating a new key pair + updating the secret. |
| AWS OIDC role ARN | GitHub repo secret `AWS_ROLE_TO_ASSUME` | ARN string (not actually secret) | — |

The Terraform state in S3 contains the RDS password as well (because the
provider needs it). The S3 bucket has:
- Versioning ON
- Server-side encryption (SSE-S3)
- Public access blocked
- `prevent_destroy = true` on the bucket resource

## Network isolation

```text
Internet
    │
   IGW
    │
┌───┴───────────────────────────────────────────────────────┐
│ VPC 10.0.0.0/16                                           │
│                                                            │
│  Public subnets (10.0.1.0/24, 10.0.2.0/24)                │
│   ┌───────────────────────────────┐                        │
│   │ EC2 cncloud-dev-app-host       │                        │
│   │  - web-sg : 80, 8080 from 0/0  │                        │
│   │  - app-sg : -                  │                        │
│   └───────┬───────────────────────┘                        │
│           │ ingress source SG ref                          │
│           ▼                                                │
│  Private subnets (10.0.10.0/24, 10.0.20.0/24)             │
│   ┌─────────────────────────────────┐                      │
│   │ RDS cncloud-dev-postgres        │                      │
│   │  - db-sg : 5432 from app-sg     │                      │
│   └─────────────────────────────────┘                      │
└────────────────────────────────────────────────────────────┘
```

Key choices:
- **No NAT Gateway.** The private subnets have no `0.0.0.0/0` route, so
  RDS cannot reach the internet at all.
- **Security-group references, not CIDRs.** The DB SG accepts `5432` from
  `app-sg`, not from `10.0.0.0/16`. If the EC2 ever loses the `app-sg`,
  the DB silently stops accepting it.
- **EC2 carries two SGs at once.** `web-sg` opens the public ports;
  `app-sg` is the identifier that the DB SG ingress rule keys on. This is
  what lets a single EC2 host both the public gateway and the internal
  services without exposing the DB.

## Things still on the to-do list

The `cncloud-gha-deployer` role currently has `PowerUserAccess`. That is
intentional during development: it makes it trivial to add new AWS resources
to Terraform without having to update the role too. Before submission /
defense, this should be replaced with an inline policy that lists
explicitly the actions the deploy workflow needs (the rough set is: `ec2:*`
on tagged resources, `rds:*`, `sqs:*`, `sns:*`, `secretsmanager:*` on
project-named secrets, `iam:PassRole` + the IAM helpers already in
`gha_deployer_iam_helper.json`, `s3:*` on the state bucket, `dynamodb:*` on
the lock table, `logs:*`, `cloudwatch:*`).

Other follow-ups in [`limitations.md`](limitations.md):
- Run Secrets Manager rotation (`automatically_after_days`).
- Replace SSH access with SSM Session Manager only (port 22 closed).
- Run `gitleaks` in CI to fail-fast on accidental secret commits.
