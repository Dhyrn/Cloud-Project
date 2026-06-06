# Setup

What you need installed and configured before you can run anything in this
repository. Estimated time end-to-end on a clean machine: **45–60 minutes**.

## 1. Local toolchain

| Tool | Version | Why | Install (macOS) |
|---|---|---|---|
| `git` | any recent | source control | `xcode-select --install` |
| AWS CLI | v2 | talk to AWS from the terminal | `brew install awscli` |
| Terraform | ≥ 1.5 | provision infra | `brew install terraform` |
| Docker Desktop | latest | build & push images (uses Buildx for cross-arch) | https://docker.com/products/docker-desktop |
| Maven | ≥ 3.9, JDK 21 | build the Spring Boot services | `brew install maven openjdk@21` |
| Python | 3.11 + venv | run Ansible | bundled with macOS; `brew install python@3.11` for fresh |
| `make` | any | shorthand for common commands | bundled with Xcode tools |

Verify everything is wired up:

```bash
git --version
aws --version                      # aws-cli/2.x
terraform -version                 # >= 1.5
docker version                     # client + server
docker buildx version              # > 0.10
mvn -v                             # JDK 21
python3 --version                  # 3.11+
```

## 2. AWS account

1. **A real AWS account** (a personal/student account works). The lab account
   is fine too if it doesn't restrict the services used here (VPC, EC2, RDS,
   SQS, IAM, Secrets Manager, S3, DynamoDB, CloudWatch, SNS).
2. **MFA on the root user** and a separate IAM user for daily work.
3. **AWS CLI configured** with that IAM user's credentials:
   ```bash
   aws configure
   # AWS Access Key ID:       AKIA....
   # AWS Secret Access Key:   ....
   # Default region name:     us-east-1
   # Default output format:   json
   ```
4. Verify:
   ```bash
   aws sts get-caller-identity
   # {"UserId": "...", "Account": "969831127354", "Arn": "arn:aws:iam::...:user/..."}
   ```

The IAM user used for the **first** Terraform apply needs admin-equivalent
rights (it has to create IAM roles, OIDC providers, S3 buckets…). After the
GitHub Actions OIDC role exists, day-to-day deploys use that instead.

## 3. SSH key pair

The EC2 instance reuses the lab key pair `week6-key`. The instance was
launched with `key_name = "week6-key"`, so SSH access requires the matching
private key on disk.

```bash
# Move the key into ~/.ssh and lock it down
mv ~/Downloads/week6-key.pem ~/.ssh/
chmod 600 ~/.ssh/week6-key.pem

# Sanity check
ls -la ~/.ssh/week6-key.pem
# -rw------- 1 you staff 1675 ... ~/.ssh/week6-key.pem
```

If you don't have the original PEM, the easiest path is to recreate the key
pair via Terraform (add an `aws_key_pair` resource) and `terraform apply` —
but that requires recreating the EC2 too. We don't do that today.

## 4. Bootstrap the AWS account (one-time, ~5 min)

This single step creates:

- S3 bucket + DynamoDB table for Terraform remote state
- SNS topic + email subscription + 2 billing alarms ($5 warn, $20 hard)
- OIDC identity provider for GitHub Actions
- IAM role `cncloud-gha-deployer` for the CI to assume

```bash
cd infrastructure/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit the email and (if you forked) the github_org / github_repo values.

terraform init
terraform plan      # expect 13 resources to add
terraform apply

# Confirm the SNS email subscription — AWS sends a confirmation link.
# Without confirming, you do NOT receive billing alarms.

# Capture the GitHub Actions role ARN
terraform output -raw gha_deployer_role_arn
# arn:aws:iam::969831127354:role/cncloud-gha-deployer
```

See **[`infrastructure/bootstrap/README.md`](../infrastructure/bootstrap/README.md)**
for what each resource does and how to recover from common failures.

## 5. GitHub repository secrets

Add these as **Repository** secrets at
`https://github.com/<your_user>/<your_repo>/settings/secrets/actions`:

| Name | Value | Where it comes from |
|---|---|---|
| `AWS_ROLE_TO_ASSUME` | the `gha_deployer_role_arn` from step 4 | `terraform output -raw gha_deployer_role_arn` |
| `DOCKERHUB_USERNAME` | your Docker Hub username | e.g. `dhirennn` |
| `DOCKERHUB_TOKEN` | a Docker Hub access token (Read+Write) | https://hub.docker.com/settings/security → New Access Token |
| `SSH_PRIVATE_KEY` | contents of `~/.ssh/week6-key.pem` | `cat ~/.ssh/week6-key.pem \| pbcopy` then paste |

**Sanity-check** the OIDC path before going further: trigger the
`aws-smoke` workflow manually (Actions tab → aws-smoke → Run workflow). It
should complete in ~15s and print the assumed role's session ARN.

## 6. GitHub environment (manual deploy gate)

For the `production` environment gate on `deploy.yml`:

- **Public repo (any plan)** or **private repo on GitHub Pro/Team**:
  Settings → Environments → New environment → `production` → check
  **Required reviewers** → add yourself.
- **Private repo on GitHub Free**: `Deployment protection rules` is not
  available. Either make the repo public, or remove the `environment:`
  blocks from `deploy.yml` and accept fully-automatic deploys.

## 7. Python venv + Ansible

```bash
# From the repo root
python3 -m venv .venv
source .venv/bin/activate

pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml

# Sanity-check (after the dev env is applied — see deployment.md)
cd ansible
ansible-inventory --graph
# Expect to see cncloud-dev-app-host inside @aws_ec2
```

## 8. Docker Hub setup

A Docker Hub account is required to publish images. If you're forking this
project, create the four repos beforehand (Docker Hub auto-creates on first
push, but explicitly creating them lets you make them public):

- `<username>/cncloud-api-gateway`
- `<username>/cncloud-user-service`
- `<username>/cncloud-product-service`
- `<username>/cncloud-order-service`

Then `docker login` once on your machine so `make push` works.

## 9. You're ready

Continue with **[`docs/deployment.md`](deployment.md)**.
