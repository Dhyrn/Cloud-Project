# environments/prod

**Intentionally not implemented in this project.**

This directory exists to mark where a production environment configuration
would live, but the scope of the course project is the **dev** environment
only. Implementing prod would mostly be a copy of `../dev/` with:

- A separate Terraform state key (e.g. `envs/prod/terraform.tfstate`).
- `multi_az = true` on the RDS module.
- A larger `instance_type` (e.g. `t3.medium`).
- `deletion_protection = true` on RDS.
- `skip_final_snapshot = false` so a snapshot is kept on destroy.
- A separate Secrets Manager secret (`cncloud-prod-db-credentials`).
- An ALB in front of the EC2 (instead of public EC2).
- A different IAM role / tighter trust policy on the GitHub OIDC role.

If a maintainer wants to add prod, the right starting point is:

```bash
cp -R ../dev/* .
# Edit backend.tf: change `key = "envs/dev/..."` to `key = "envs/prod/..."`
# Edit terraform.tfvars: environment = "prod", instance_type = "t3.medium", ...
terraform init
terraform plan
```

See [`docs/limitations.md`](../../../../docs/limitations.md) for the full
list of what we deliberately scoped out and why.
