# Deployment

How to go from a clean repo + a bootstrapped AWS account to a running cncloud
stack. Two flows are supported:

1. **Manual** — from your laptop, using the `Makefile`. Best for development
   and the first end-to-end run.
2. **GitHub Actions** — every push to `main` triggers `deploy.yml` and
   redeploys after a single click of approval.

Both flows produce the same result.

---

## Flow A — manual deploy

### A1. Provision the dev environment

```bash
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# At minimum, terraform.tfvars must set key_name = "week6-key".

terraform init                  # uses S3 backend created in bootstrap
terraform plan                  # expect ~29 resources on a fresh apply
terraform apply
```

After `apply`, useful outputs:

```bash
terraform output ec2_public_ip
terraform output sqs_queue_url
terraform output db_endpoint
terraform output db_secret_arn
```

These are also accessible via `make tf-output`.

### A2. Build and push the application images

```bash
cd <repo root>

# Builds JARs with Maven (skips tests due to issue #17)
make package

# Cross-builds linux/amd64 images via buildx and pushes to Docker Hub.
# Creates the cncloud-builder buildx instance if missing.
make push
```

`make ship` is shorthand for `package + push` in one shot.

The Dockerfile in each service is a runtime-only image (it copies the
pre-built JAR), so `make package` MUST run before `make push`.

### A3. Deploy with Ansible

```bash
# Sanity-check (optional but recommended on first run)
make ansible-inventory          # should list cncloud-dev-app-host
make sanity-test                # hello-world end-to-end check (~3 min)

# Actual deploy
make deploy
```

What `make deploy` does:

1. Reads the RDS credentials from AWS Secrets Manager (delegated to your
   local AWS CLI — `no_log` so they never appear in playbook output).
2. Ensures a 2 GB swap file exists on the EC2 (idempotent).
3. Copies `docker-compose.aws.yml` to `/opt/cncloud/docker-compose.yml`.
4. Renders `/opt/cncloud/.env` (mode 0600) with the DB host/user/password
   and the SQS queue URL.
5. `docker compose pull` and `docker compose up -d --force-recreate
   --remove-orphans`.
6. Waits up to ~12 minutes for `api-gateway` health to return 200.

### A4. Validate

```bash
IP=$(make tf-ec2-ip)

# Gateway health
curl -i http://$IP:8080/actuator/health
# {"status":"UP", ...}

# Routes
curl -i http://$IP:8080/api/products            # 200 []
curl -i http://$IP:8080/api/users               # 200 []
curl -i http://$IP:8080/api/orders              # 200 []

# Create a product (triggers SQS publish + consume)
curl -X POST http://$IP:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"demo","description":"manual deploy",
       "price":9.99,"stockQuantity":1,"category":"DEMO"}'
# 201 Created

# Verify the message went through SQS
aws sqs get-queue-attributes \
  --queue-url $(make tf-sqs-url) \
  --attribute-names ApproximateNumberOfMessages \
                    ApproximateNumberOfMessagesNotVisible

# Verify the consumer logged it
ssh -i ~/.ssh/week6-key.pem ec2-user@$IP \
  "docker logs order-service 2>&1 | grep 'SQS product event' | tail -3"
```

---

## Flow B — GitHub Actions deploy

Triggered automatically by `git push origin main` (or manually via "Run
workflow" on the Actions page). Defined in
[`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml).

### Pipeline stages

```text
┌─────────────────────────┐
│ build-and-push (matrix) │  ~5 min   in parallel for the 4 services
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ terraform-apply         │  ⏸  waits for manual approval
│   environment: production│
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ ansible-deploy          │  ~10 min  pulls images + force-recreate + health
└─────────────────────────┘
```

### Approving the production gate

1. Open the workflow run on the Actions tab.
2. The `terraform-apply` job will display **"Review pending deployments"**.
3. Click → check `production` → **Approve and deploy**.

Both `terraform-apply` and `ansible-deploy` then run automatically.

### Image tagging

Each build pushes two tags:

- `<sha>` — the immutable Git SHA of the commit (used internally by
  `deploy.yml` to ensure the EC2 pulls exactly the build that was built).
- `latest` — the rolling pointer (used for ad-hoc `make deploy` from your
  laptop).

To roll back, redeploy a previous SHA tag by running the workflow on the
older commit.

---

## Verification checklist (defense-day-ready)

| Check | How |
|---|---|
| 4 containers Up + healthy | `ssh ... 'docker ps'` |
| `/actuator/health` returns 200 on each service | `curl ... :8080/actuator/health` |
| POST creates a product in RDS | `curl -X POST ... \| grep id` |
| Product survives container restart | `docker restart product-service && sleep 60 && curl ...` |
| SQS DLQ is empty | `aws sqs get-queue-attributes --queue-url $(make tf-sqs-url)-dlq` |
| RDS data persists across `terraform apply` | (don't actually destroy) — read schema with `\dn` from psql in container |

---

## Tear down (end of day)

```bash
# Application stack
make tf-destroy
# (DB snapshots are skipped in dev, so this is fast)

# Bootstrap (only when retiring the account)
cd infrastructure/bootstrap
terraform destroy
# The S3 state bucket has prevent_destroy=true — remove that flag first
# if you really want to delete it.
```

A full destroy takes ~5 min. Cost goes to ~$0 immediately.

---

## Common deploy errors

| Symptom | Cause | Fix |
|---|---|---|
| `make push` fails with `Error: failed to connect to docker API` | Docker Desktop not running | `open -a Docker`, wait 30s, retry |
| `exec /opt/java/openjdk/bin/java: exec format error` in container logs | Image built on Apple Silicon (arm64), not amd64 | `make push` uses buildx with `--platform linux/amd64`; if you bypass it, the EC2 can't run the binary |
| `Caused by: java.lang.ClassNotFoundException: SqsClient` | Stale JAR without AWS SDK dependency | Always use `mvn clean package`, not `mvn package` — handled by Makefile |
| `Could not load credentials from any providers` in CI | `AWS_ROLE_TO_ASSUME` secret missing or wrong | Check repo Settings → Secrets |
| Ansible `Read RDS credentials from Secrets Manager` fails | Local AWS CLI session expired | `aws configure` or `aws sso login` |
| `make deploy` hangs in "Wait for api-gateway healthcheck" | Spring Boot startup is slow (~50 s on t3.small) | Be patient; default timeout is ~12 min |
| Container in `Restarting (1)` loop | Spring Boot crash — look at logs | `docker logs <name> 2>&1 \| tail -50` |
