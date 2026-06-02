# Reuse Map — what to bring from week1–week10

Audit done on Day 1. For every artefact found in the lab folders we decide
one of: **REUSE** (copy as-is), **ADAPT** (copy and modify), **REFERENCE**
(keep as docs only), **DISCARD** (do not use), **SECURITY** (must be
rotated / never committed).

Legend for `Target`: where it lands in this repo (or `—` if discarded).

---

## SECURITY ALERTS (act before anything else)

| Source | Issue | Action |
|---|---|---|
| `week4/cloud-lab-user_accessKeys.csv` | **REAL AWS access key + secret** committed to disk | **Rotate / disable the key in IAM console NOW.** Add `*credentials*.csv` to `.gitignore` (already done). Never copy into this repo. |
| `week7/terraform-week7/terraform.tfvars` | `db_password = "13kumar13"` hardcoded | Use Secrets Manager + `terraform.tfvars.example` template, real values via env vars or AWS Secrets Manager. |
| `week5/week5-key.pem`, `week6/week6-key.pem` | Private SSH keys | Generate a fresh key pair for the project. Add `*.pem` to `.gitignore` (already done). |

---

## Week 1 — AWS Setup & Billing

| File | Verdict | Target | Notes |
|---|---|---|---|
| `cloudwatch-billing-alert.yaml` | **ADAPT** | `infrastructure/terraform/modules/billing/` (new) | Converter de CloudFormation para Terraform. Cria SNS topic + email subscription + CloudWatch billing alarm. Ótimo para cobrir o "billing alarm — non-negotiable" do enunciado. |
| `iam-role-template.yaml` | REFERENCE | — | Padrão CFN para IAM com least-privilege. Modelo mental, refazer em Terraform. |

## Week 4 — IAM & AWS CLI

| File | Verdict | Target | Notes |
|---|---|---|---|
| `createresources.py` | DISCARD | — | Trabalho equivalente é feito por Terraform agora. |
| `awsvalidator.py` | REUSE | `scripts/awsvalidator.py` | Útil para `make verify-aws` — valida que o IAM tem acesso a S3/EC2 antes do CI correr. Adicionar checks para SQS e RDS. |
| `student-policy.json` | REFERENCE | — | Modelo de least-privilege. Inspira a policy do gha-deployer e do EC2 instance profile. |
| `trust-policy.json` | REFERENCE | — | Trust policy básica para EC2. Vamos precisar de uma análoga para OIDC do GitHub. |

## Week 5 — VPC

| File | Verdict | Target | Notes |
|---|---|---|---|
| `create-vpc.sh` | DISCARD | — | Substituído pelo módulo `vpc` em Terraform (week8 já tem). Manter como documentação da arquitectura para a defesa. |

## Week 6 — EC2 & RDS

| File | Verdict | Target | Notes |
|---|---|---|---|
| `launch-ec2.sh` | DISCARD | — | Substituído por Terraform. |
| `deploy-container.sh` | ADAPT | `ansible/roles/app-deploy/` | A lógica (pull image → stop old → run new → check) já está no `deploy-app.yml` da week10. Manter como referência para a role `app-deploy`. |
| `get-instance-ip.sh` | DISCARD | — | Substituído por Terraform outputs / Ansible aws_ec2 inventory. |

## Week 7 — Terraform Fundamentals

| File | Verdict | Target | Notes |
|---|---|---|---|
| `main.tf` (EC2 + SG + EIP + user_data) | ADAPT | `infrastructure/terraform/modules/compute/` | A parte do user_data com `yum install docker` é boa — manter como fallback se Ansible falhar. |
| `vpc.tf` (VPC monolítica) | DISCARD | — | Superado pelo módulo `vpc` da week8 (com for_each, validation, melhor). |
| `rds.tf` | **ADAPT** | `infrastructure/terraform/modules/db/` | Base sólida: Postgres 17, db.t3.micro, subnet group privada, storage_encrypted. Adaptar para: receber inputs (vpc_id, subnet_ids, app_sg_id), password via Secrets Manager (NÃO via var), backup_retention_period > 0 em prod. |
| `variables.tf` / `outputs.tf` | REFERENCE | — | Estrutura útil; reaproveitar no projeto unificado. |
| `terraform.tfvars` | **SECURITY/DISCARD** | — | Tem password hardcoded. Não copiar. Criar `.example` sem senha. |

## Week 8 — Terraform Modules

| File | Verdict | Target | Notes |
|---|---|---|---|
| `main.tf` (módulos network + compute) | **ADAPT** | `infrastructure/terraform/environments/dev/main.tf` | Base perfeita para o root module do dev. Adicionar módulo `db` (week7) e `queue` (week9). |
| `modules/vpc/main.tf` | **REUSE** | `infrastructure/terraform/modules/vpc/main.tf` | Excelente: for_each, public/private subnets, IGW, public RT. Falta: NAT Gateway opcional, private route table. Vou adicionar como `nat_enabled` flag. |
| `modules/vpc/variables.tf` + `outputs.tf` | **REUSE** | `infrastructure/terraform/modules/vpc/` | Outputs já expõem `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `internet_gateway_id` — exatamente o que precisamos. |
| `modules/ec2/main.tf` | **ADAPT** | `infrastructure/terraform/modules/compute/main.tf` | Boa base com dynamic ingress e Amazon Linux AMI. Falta: separar `web-sg` de `app-sg`, suportar 2+ instâncias (para 2 AZs), iam_instance_profile, user_data para instalar Docker como bootstrap minimal. |
| `modules_public.tf` (community vpc) | REFERENCE | — | Mostra que sabes usar módulos da comunidade. Pode ser opção para refactor futuro mas mantemos custom para teres controlo total na defesa. |
| `terraform.tfvars` | REUSE como base | `infrastructure/terraform/environments/dev/terraform.tfvars.example` | Sem secrets. Renomear "week8" → "cncloud" / env. |

## Week 9 — SQS

| File | Verdict | Target | Notes |
|---|---|---|---|
| `infra/week9-sqs/main.tf` | **REUSE** | `infrastructure/terraform/modules/queue/main.tf` | Excelente: queue standard + DLQ com redrive_policy, long polling, visibility timeout 60s. Manter exatamente assim. |
| `infra/week9-sqs/fifo.tf` | OPCIONAL | `infrastructure/terraform/modules/queue/fifo.tf` | Variante FIFO. Mantém se queres a opção; caso contrário descartar (nem todas as queues precisam ser FIFO). Decisão: **descartar** — simplifica defesa. |
| `infra/week9-sqs/variables.tf` + `outputs.tf` | **REUSE** | `infrastructure/terraform/modules/queue/` | Bom design. Renomear `name_prefix` default de `cn-course` → `cncloud-${var.environment}`. |
| `sqs-policy.json` | **ADAPT** | `infrastructure/terraform/modules/compute/iam.tf` | Convert a JSON policy num `aws_iam_policy_document` data resource. **NOTA:** o Resource hardcoded `arn:aws:sqs:us-east-1:969831127354:cn-course-product-events` é da própria conta do utilizador (confirmado via `aws_caller_identity` no bootstrap, account_id = 969831127354), mas o nome da queue (`cn-course-product-events`) era ad-hoc — vamos substituir por reference dinâmica ao output do módulo queue (`cncloud-dev-product-events`). |

## Week 10 — Ansible

| File | Verdict | Target | Notes |
|---|---|---|---|
| `configure-ec2.yml` | **ADAPT** | `ansible/playbooks/configure-ec2.yml` | Tem `yum install -y git java-21-amazon-corretto maven` — não precisamos de Java/Maven no host (corre em container). Limpar para só instalar Docker + utils. |
| `deploy-app.yml` | **ADAPT** | `ansible/playbooks/deploy-app.yml` | Lógica boa mas usa `command: docker run` em vez do módulo `community.docker.docker_container` (não idempotente). Refactor para módulo nativo. Parametrizar image_name por serviço. |
| `playbook.yml` | DISCARD | — | Versão sem roles, superseded por playbook-role.yml. |
| `playbook-role.yml` | **REUSE** como template | `ansible/playbooks/site.yml` | Padrão correto (com roles). Vai virar o playbook orquestrador. |
| `roles/docker/` | **REUSE** | `ansible/roles/docker/` | Role limpa: tasks, defaults, handlers. Copiar tal-qual. |
| `inventory.ini` | **ADAPT** | `ansible/inventory/aws_ec2.yml` | Tem IP hardcoded (`34.201.24.250`) e key path (`~/.ssh/week6-key.pem`). Substituir por dynamic inventory plugin `amazon.aws.aws_ec2` que descobre EC2s por tag. |

## docker-compose & microsserviços (week2 + week9)

| Source | Verdict | Notes |
|---|---|---|
| `microservices-project/docker-compose.yml` (week9) | **REUSE** | Já copiado. **Adaptar mais tarde:** parametrizar SQS URL/region por env vars sem defaults (forçar ser injectado pelo Ansible). |
| Dockerfiles do product/order-service (week9) | **REUSE** | Já copiados. |
| Código SQS (publisher, consumer, properties, events) | **REUSE** | Já mergeado pelo overlay. |
| `sqs-policy.json` no root do microservices | **DISCARD do root** | Recolocar dentro de `infrastructure/terraform/modules/compute/policies/`. |

---

## What we need to CREATE (não vem dos labs)

| Item | Onde | Porquê |
|---|---|---|
| `infrastructure/bootstrap/` (S3 + DynamoDB para remote state) | new | Não havia em nenhum lab. Crítico para trabalho em grupo. |
| OIDC IAM provider + role para GitHub Actions | `infrastructure/terraform/modules/iam-github-oidc/` | Não havia em nenhum lab. Crítico para CI/CD seguro. |
| Secrets Manager para DB password | `infrastructure/terraform/modules/db/secret.tf` | Substitui `var.db_password`. |
| `.github/workflows/{ci,deploy}.yml` | `.github/workflows/` | Não havia em nenhum lab. 15% da nota. |
| `Makefile` ou `Taskfile` | root | DX. Faz `make up`, `make deploy`, `make destroy` triviais. |
| Documentação final (README, setup, deployment, security, limitations) | `docs/` | 5% da nota. |

---

## Decisões tomadas (Day 1)

1. **SQS:** Standard apenas, descartar FIFO. → `infra/week9-sqs/fifo.tf` **DISCARD**.
2. **EC2 em dev:** 1 instância t3.micro com todos os containers via docker-compose.
3. **NAT Gateway:** Nenhum. Mesma abordagem dos labs week5/7/8. As subnets privadas são só para RDS.
4. **Billing alarm:** Portado de CloudFormation (week1) para Terraform (consistência).
5. **Key pair:** Reutilizar `week6-key` existente na conta AWS. Terraform usa `key_name = "week6-key"` como referência (não cria a key pair).
