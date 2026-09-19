# Ansible Provisioning Setup — WLJ.Devops

## Context

Branch `feature/wjindra/ansible-provisioning` exists but has no Ansible content yet. The README already documents a target architecture — three Multipass VMs (`qa-pipeline`, `qa-web`, `qa-db`, already provisioned via Terraform, IPs `192.168.0.19/.18/.17`), a target `ansible/` layout, and two separate ADO pipelines (`WLJ.DevOps` for provisioning, `WLJ.Payments` for app deploys) — but none of it is built. This plan implements that: SSH access from the host to the VMs, the Ansible playbooks/roles, a Dockerized self-hosted ADO agent running on the host that drives provisioning, and the `WLJ.DevOps` pipeline itself.

Two agents were deliberately chosen (confirmed in conversation), both on-prem:
- **Agent #1** — a Docker container on the root host, bundling the ADO agent runtime + Ansible. Drives the `WLJ.DevOps` pipeline (Ansible provisioning only — Terraform stays manual, see Open Assumptions).
- **Agent #2** — the Azure Pipelines self-hosted agent installed *inside* `qa-pipeline` by Ansible's `pipeline.yml`. Drives the future `WLJ.Payments` pipeline (app builds/deploys/migrations). Not built in this pass beyond installing the agent + self-hosted registry.

This also resolves the chicken-and-egg problem of "the pipeline that configures `qa-pipeline` needs an agent, but the agent lives on `qa-pipeline`": Agent #1 is registered once, manually, outside any pipeline, and its first `WLJ.DevOps` run installs Agent #2.

## 1. Terraform: SSH bootstrap

No SSH keypair exists on the host yet (`~/.ssh/authorized_keys` is empty). `multipass_instance` (the `todoroff/multipass` provider) has no SSH-key attribute — the only injection points are `cloud_init`/`cloud_init_file`, which we leave untouched (still Canonical's upstream Docker cloud-init).

Instead, use the provider's `multipass_file_upload` resource (maps to `multipass transfer`, works without SSH) plus a guarded append via `multipass exec` (also SSH-independent) — this avoids clobbering the `authorized_keys` entries multipassd's own `exec`/`transfer`/`shell` channel relies on.

**New file `terraform/ssh_bootstrap.tf`:**
- `tls_private_key` (`hashicorp/tls` provider, ED25519) generates the keypair.
- `local_sensitive_file` / `local_file` (`hashicorp/local` provider) write the private/public key to `var.ansible_private_key_path` (default `~/.ssh/ansible_ed25519`) on the host.
- Per VM (`qa_pipeline`, `qa_web`, `qa_db`): a `multipass_file_upload` resource uploads the public key to a scratch path (`var.ansible_pubkey_scratch_path`, default `/tmp/ansible_key.pub`), then a `terraform_data` resource with a `local-exec` provisioner runs:
  ```
  multipass exec <vm> -- bash -c '
    mkdir -p /home/ubuntu/.ssh && chmod 700 /home/ubuntu/.ssh
    touch /home/ubuntu/.ssh/authorized_keys
    grep -qxFf <scratch_path> /home/ubuntu/.ssh/authorized_keys || cat <scratch_path> >> /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys && chown -R ubuntu:ubuntu /home/ubuntu/.ssh
  '
  ```
  Idempotent (grep-guarded), depends on the file_upload resource.

Add `tls` and `local` to `required_providers` in `terraform/main.tf`. Add `ansible_private_key_path` and `ansible_pubkey_scratch_path` variables to `terraform/variables.tf`. Leave `terraform/outputs.tf`'s existing `*_lan_ip` block and its `TODO(ansible-pr)` comment untouched — resolving that TODO (dynamic inventory) is out of scope for this pass.

**Tradeoff to flag:** the private key ends up in `terraform.tfstate` (already gitignored) since `tls_private_key` is Terraform-native/idempotent rather than a shelled-out `ssh-keygen`.

## 2. `ansible/` directory

```
ansible/
├── ansible.cfg              -- roles_path, host_key_checking off, become=sudo; no hardcoded private_key_file (passed via --private-key)
├── requirements.yml         -- ansible.netcommon, ansible.utils, community.docker
├── inventory/qa.ini         -- static: qa-pipeline/.19, qa-web/.18, qa-db/.17, ansible_user=ubuntu
├── group_vars/all.yml       -- ansible_python_interpreter only; no secrets (passed via -e at run time)
├── playbooks/
│   ├── pipeline.yml         -- roles: ado_agent (installs Agent #2), docker_app (self-hosted registry:2)
│   ├── web.yml               -- scaffold only: /opt/app dir + app_net docker network, no real deploy (belongs to WLJ.Payments)
│   └── db.yml                -- role: docker_app (postgres:16, named volume, creds via vars)
└── roles/
    ├── docker_app/           -- generic community.docker.docker_container wrapper (name/image/ports/env/volumes/restart_policy)
    └── ado_agent/             -- downloads/configures/registers the ADO Linux agent as a systemd service, idempotent (checks for existing .agent config)
```

Static inventory matches README's documented target layout exactly. Dynamic inventory generation (tied to the `TODO(ansible-pr)` in `outputs.tf`) is explicitly deferred.

`docker_app` role is reused by `pipeline.yml` (registry) and `db.yml` (postgres) but deliberately *not* used by `web.yml`, which stays a scaffold since real app-deploy logic belongs to the separate WLJ.Payments pipeline/repo.

## 3. Agent #1 — Dockerized self-hosted ADO agent

**New top-level `agent/` directory** (sibling to `terraform/`/`ansible/`, not nested — it's a pipeline-runner image, not Ansible-internal content):
```
agent/
├── Dockerfile      -- ubuntu:24.04 base; installs ansible-core + collections from ansible/requirements.yml; downloads a pinned Azure Pipelines agent release; openssh-client for connecting out
├── entrypoint.sh   -- standard MS container-agent pattern: config.sh --unattended from AZP_URL/AZP_TOKEN/AZP_POOL/AZP_AGENT_NAME env vars, traps SIGTERM for clean remove.sh, execs run.sh
└── README.md       -- build/run instructions
```
Build with repo root as context (`docker build -f agent/Dockerfile -t wlj-devops-agent .`) so it can `COPY ansible/requirements.yml`.

One-time manual registration (not part of any pipeline):
```
docker run -d --name wlj-devops-agent --restart unless-stopped \
  -e AZP_URL=https://dev.azure.com/<org> -e AZP_TOKEN=<PAT> \
  -e AZP_POOL=onprem-infra -e AZP_AGENT_NAME=onprem-agent-1 \
  wlj-devops-agent
```
No SSH key is baked into the image or bind-mounted at registration — it's delivered fresh per pipeline run via an ADO Secure File download step (see §4), so key rotation doesn't require rebuilding/restarting the agent container.

## 4. `WLJ.DevOps` pipeline — `/azure-pipelines.yml`

Repo root, targeting the `onprem-infra` pool (Agent #1). Two stages:
- **Validate** — `ansible-playbook --syntax-check` for all three playbooks.
- **Provision** — `DownloadSecureFile@1` pulls the `ansible_ed25519` private key, then runs `pipeline.yml` → `web.yml` → `db.yml` in order via `ansible-playbook -i ansible/inventory/qa.ini <playbook> --private-key <downloaded path> -e ...`, with secrets (`ADO_ORG_URL`, `ADO_AGENT_PAT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) sourced from a `wlj-devops-secrets` variable group.

`terraform/**` is deliberately **not** a trigger path and Terraform is **not** run by this pipeline — see Open Assumptions #1.

## 5. `.gitignore` additions

```
# Ansible
*.retry
ansible/collections/
ansible_ed25519
ansible_ed25519.pub

# ADO self-hosted agent local working state
agent/_work/
agent/_diag/
agent/.agent
agent/.credentials
agent/.credentials_rsaparams
agent/.service
agent/.path
agent/*.log
```

## 6. Manual ADO-portal setup (not code — user does this by hand; no `az`/`gh` CLI available against this org)

1. Create agent pool `onprem-infra` (for Agent #1).
2. Create a second agent pool for Agent #2 (default name `qa-payments` — confirm/rename).
3. Generate a one-time registration PAT for Agent #1 (`Agent Pools: Read & manage`), used live at `docker run`, not stored.
4. Generate a PAT for Agent #2, stored as `ADO_AGENT_PAT` in the variable group (consumed every `pipeline.yml` run, since the `ado_agent` role re-registers idempotently).
5. Upload `~/.ssh/ansible_ed25519`'s contents as Secure File `ansible_ed25519`; authorize the pipeline to use it.
6. Create variable group `wlj-devops-secrets` (`ADO_ORG_URL`, `ADO_AGENT_PAT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`); authorize the pipeline.
7. Create the `WLJ.DevOps` pipeline pointing at `/azure-pipelines.yml`.
8. Approve first-run prompts for Secure File / variable group access.

## Implementation & verification order

1. `ssh_bootstrap.tf` → `terraform/apply.sh`. Verify: `ssh -i ~/.ssh/ansible_ed25519 ubuntu@<each IP> true` succeeds for all three; `multipass exec qa-pipeline -- cat ~/.ssh/authorized_keys` shows the key *appended*; `multipass shell qa-pipeline` still works (multipassd's own channel undisturbed).
2. Scaffold `ansible/` (cfg, inventory, group_vars, empty roles). Install Ansible natively on host for local dry runs (separate from Agent #1's containerized copy). `ansible -i ansible/inventory/qa.ini all -m ping --private-key ~/.ssh/ansible_ed25519`.
3. `roles/docker_app` + `db.yml` — run manually against `qa-db`; verify Postgres container + volume persistence.
4. `web.yml` scaffold — run manually against `qa-web`.
5. `roles/ado_agent` + `pipeline.yml` — do ADO steps 2 & 4 first; run manually against `qa-pipeline`; verify Agent #2 shows Online and `registry:2` is reachable on :5000.
6. `agent/Dockerfile` + `entrypoint.sh` — build, then do ADO steps 1 & 3, run the one-time registration; verify Agent #1 shows Online.
7. `azure-pipelines.yml` — write it, do ADO steps 5–8.
8. First real pipeline run (Validate → Provision). Rerun once to confirm idempotency.
9. Follow-up (not this pass): update README's Next Steps checklist and repo-structure diagram/architecture text to include `agent/` and reflect Ansible actually running containerized in the pipeline path.

## Open assumptions (flagging for visibility — defaults chosen, easy to override)

1. **Terraform stays manual, out of any pipeline** (per README's existing IaC Strategy table) — `PLANNING.md`'s note mentioned "WLJ.DevOps pipeline ... Terraform + Ansible," which this plan does not implement literally. Followed the more detailed, explicit README brief instead; the `multipass` CLI's snap-confinement issue (documented in README) makes running Terraform from inside Agent #1's container specifically risky anyway.
2. Secrets via ADO Secure Files/variable groups, not Ansible Vault — matches the pivot toward doing this in ADO, no separate explicit confirmation.
3. Agent #2's pool name (`qa-payments`) is a placeholder — needs a real decision.
4. `community.docker` collection (+ either the Python `docker` SDK or `docker_compose_v2` shelling to the CLI) is needed for `docker_app`'s container tasks — not explicitly requested, added out of necessity.
5. ADO agent version pinned as a Dockerfile `ARG` (Microsoft provides no "latest" URL) — needs an update policy/owner.
6. Agent #1 bundles Ansible in Docker, which is a departure from the README's stated rationale for keeping Ansible host-native ("no container-runtime dependency"). This plan also installs Ansible natively on the host for manual dry runs (step 2 above), but the pipeline path always uses the containerized copy — README's tooling list/diagram will need a follow-up edit to stay accurate.
7. No manual-approval ADO Environment gating the Provision stage by default (PLANNING.md's gate note was framed around `terraform apply`, which isn't in this pipeline at all) — can be added later if wanted.

## Verification

Primarily manual (infra provisioning, no test suite): SSH connectivity checks, `ansible ... -m ping`, `ansible-playbook --syntax-check`, then real playbook runs against each VM checked via `systemctl status`/`docker ps` on the VM and the ADO portal (agent Online status, pipeline run success), as detailed in the numbered order above. Rerun playbooks a second time to confirm idempotency (no spurious changes reported).
