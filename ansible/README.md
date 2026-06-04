# ansible/

Configuration management for the EC2 host(s) provisioned by
`infrastructure/terraform/environments/dev`.

## Layout

```
ansible/
├── ansible.cfg                 # picked up automatically when you run from here
├── requirements.txt            # python deps (ansible-core, boto3, botocore)
├── requirements.yml            # ansible collections (amazon.aws, community.docker)
├── inventory/
│   ├── aws_ec2.yml             # dynamic inventory — finds EC2s by tag
│   └── group_vars/
│       └── all.yml             # user, ssh key path, python interpreter
│                               # (Ansible auto-discovers group_vars/ next to inventory)
├── roles/
│   └── docker/                 # ensure Docker is installed + running (idempotent)
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       ├── defaults/main.yml
│       └── meta/main.yml
└── playbooks/
    ├── sanity-test.yml         # task #7: end-to-end plumbing test
    └── deploy-app.yml          # task #8: pull images + docker compose up
```

## First-time setup (do this once per machine)

```bash
# From the repo root
python3 -m venv .venv
source .venv/bin/activate
pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml
```

Make sure your SSH key is at `~/.ssh/week6-key.pem` (or set
`ANSIBLE_PRIVATE_KEY_FILE=/path/to/key.pem`). On macOS:

```bash
chmod 600 ~/.ssh/week6-key.pem
```

And make sure your AWS CLI is configured (the inventory plugin reads
your default profile):

```bash
aws sts get-caller-identity
```

## Verify the dynamic inventory finds the EC2

```bash
cd ansible
ansible-inventory --graph
```

Expected output:

```
@all:
  |--@aws_ec2:
  |  |--cncloud-dev-app-host
  |--@env_dev:
  |  |--cncloud-dev-app-host
  |--@project_cncloud:
  |  |--cncloud-dev-app-host
  |--@name_cncloud_dev_app_host:
  |  |--cncloud-dev-app-host
```

The display name comes from the `Name` tag. The actual SSH target is
derived inside the inventory file via `compose: ansible_host:
public_ip_address`. To confirm:

```bash
ansible aws_ec2 -m debug -a "msg={{ ansible_host }}"
# should print the public IP, e.g. 44.223.15.90
```

If `@aws_ec2:` is empty, no EC2 matched the tag filters — confirm
`terraform apply` succeeded and that the instance has the expected tags
(`Project=cncloud`, `Environment=dev`).

## Run the sanity test (task #7)

```bash
cd ansible
ansible-playbook playbooks/sanity-test.yml
```

What it does:

1. Waits for SSH (in case the EC2 is still booting).
2. Re-runs the `docker` role (idempotent — should be all `ok`).
3. Pulls and runs `hello-world`.
4. Asserts the magic string is in the output.

A successful run ends with:

```
PLAY RECAP **************************************************************
44.223.15.90 : ok=N changed=0 unreachable=0 failed=0 ...
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `UNREACHABLE! Failed to connect to the host via ssh` | SG blocks 22, wrong key, or EC2 still booting | `allow_ssh = true` in tfvars, key file has 0600, retry after 30s |
| `aws_ec2_inventory.aws_ec2: no hosts matched` | Tag filter mismatch | Check `aws ec2 describe-instances --filters "Name=tag:Project,Values=cncloud"` |
| `ImportError: No module named boto3` on local machine | venv not active or pip install missed | `source .venv/bin/activate && pip install -r ansible/requirements.txt` |
| `amazon-linux-extras: command not found` | EC2 is NOT Amazon Linux 2 | Confirm AMI filter in the compute module |
