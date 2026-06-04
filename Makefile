###############################################################################
# Makefile — common workflows for the cncloud project.
#
# Conventions:
#   - All commands are safe to re-run.
#   - `make help` lists targets with one-line descriptions.
###############################################################################

SERVICES        := api-gateway user-service product-service order-service
DOCKER_HUB_USER ?= dhirennn
IMAGE_TAG       ?= latest
TF_DIR          := infrastructure/terraform/environments/dev

# Target platform of the EC2 host. amd64 because all AWS general-purpose
# instances (t3.*, t2.*) are x86_64. If you build on Apple Silicon, this
# forces buildx to cross-compile via QEMU instead of producing arm64 images
# that fail with "exec format error" on the EC2.
TARGET_PLATFORM := linux/amd64

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ----------------------------------------------------------------------------- #
# Build + push application containers
# ----------------------------------------------------------------------------- #

.PHONY: package
package: ## mvn clean package for all 4 services (skips test compile + run)
	@for svc in $(SERVICES); do \
	  echo ">> mvn clean package $$svc"; \
	  (cd $$svc && mvn -B -Dmaven.test.skip=true clean package) || exit 1; \
	done

.PHONY: test
test: ## mvn test for all 4 services (run tests; will surface SQS test compile issue)
	@for svc in $(SERVICES); do \
	  echo ">> mvn test $$svc"; \
	  (cd $$svc && mvn -B test) || exit 1; \
	done

.PHONY: buildx-setup
buildx-setup: ## one-time: ensure a buildx builder that supports linux/amd64 exists
	@docker buildx inspect cncloud-builder >/dev/null 2>&1 || \
	  docker buildx create --name cncloud-builder --use --bootstrap

.PHONY: images
images: buildx-setup ## docker buildx build for linux/amd64 + load locally (must `make package` first)
	@for svc in $(SERVICES); do \
	  echo ">> buildx build --load $$svc"; \
	  docker buildx build \
	    --builder cncloud-builder \
	    --platform $(TARGET_PLATFORM) \
	    --load \
	    -t $(DOCKER_HUB_USER)/cncloud-$$svc:$(IMAGE_TAG) \
	    $$svc || exit 1; \
	done

.PHONY: push
push: buildx-setup ## docker buildx build for linux/amd64 + push to Docker Hub (login first)
	@for svc in $(SERVICES); do \
	  echo ">> buildx build --push $$svc"; \
	  docker buildx build \
	    --builder cncloud-builder \
	    --platform $(TARGET_PLATFORM) \
	    --push \
	    -t $(DOCKER_HUB_USER)/cncloud-$$svc:$(IMAGE_TAG) \
	    $$svc || exit 1; \
	done

.PHONY: ship
ship: package push ## package + cross-build + push in one go (recommended)

# ----------------------------------------------------------------------------- #
# Infrastructure
# ----------------------------------------------------------------------------- #

.PHONY: tf-init tf-plan tf-apply tf-destroy tf-output
tf-init: ## terraform init for the dev environment
	cd $(TF_DIR) && terraform init

tf-plan: ## terraform plan for the dev environment
	cd $(TF_DIR) && terraform plan

tf-apply: ## terraform apply for the dev environment
	cd $(TF_DIR) && terraform apply

tf-destroy: ## terraform destroy for the dev environment (use at end-of-day to save cost)
	cd $(TF_DIR) && terraform destroy

tf-output: ## show all terraform outputs (ec2 ip, sqs url, db endpoint, ...)
	cd $(TF_DIR) && terraform output

# ----------------------------------------------------------------------------- #
# Ansible
# ----------------------------------------------------------------------------- #

.PHONY: ansible-inventory sanity-test deploy
ansible-inventory: ## list the EC2 hosts discovered by the dynamic inventory
	cd ansible && ansible-inventory --graph

sanity-test: ## run the hello-world plumbing test (task #7)
	cd ansible && ansible-playbook playbooks/sanity-test.yml

deploy: ## pull images + docker compose up on the EC2 host (task #8)
	cd ansible && ansible-playbook playbooks/deploy-app.yml

# ----------------------------------------------------------------------------- #
# Helpers
# ----------------------------------------------------------------------------- #

.PHONY: tf-ec2-ip tf-sqs-url
tf-ec2-ip: ## print the EC2 public IP
	@cd $(TF_DIR) && terraform output -raw ec2_public_ip

tf-sqs-url: ## print the SQS queue URL
	@cd $(TF_DIR) && terraform output -raw sqs_queue_url

.PHONY: ssh
ssh: ## ssh to the EC2 (uses the ssh_command output)
	@cd $(TF_DIR) && eval "$$(terraform output -raw ssh_command)"
