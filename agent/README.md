# Agent #1 — on-host self-hosted ADO agent

Dockerized Azure Pipelines self-hosted agent bundling Ansible, used to run
the `WLJ.DevOps` pipeline (Ansible provisioning) from the root host. Its
first run installs Agent #2 (the Azure Pipelines agent on `qa-pipeline`)
via `ansible/playbooks/pipeline.yml`.

## Build

Run from the repo root, not from inside `agent/`, so the build context can
reach `ansible/requirements.yml`:

```bash
docker build -f agent/Dockerfile -t wlj-devops-agent .
```

## One-time registration

Requires a registration PAT scoped to `Agent Pools: Read & manage` in the
`onprem-infra` pool (see `docs/ansible-provisioning-plan.md` for the full
manual ADO setup steps). The PAT is only used live at registration time —
it is not baked into the image or stored in the container.

```bash
docker run -d --name wlj-devops-agent --restart unless-stopped \
  -e AZP_URL=https://dev.azure.com/<org> \
  -e AZP_TOKEN=<registration PAT> \
  -e AZP_POOL=onprem-infra \
  -e AZP_AGENT_NAME=onprem-agent-1 \
  wlj-devops-agent
```

The SSH private key used by Ansible inside pipeline jobs is not mounted
into this container — it's downloaded fresh per pipeline run via an ADO
Secure File step (see `/azure-pipelines.yml`), so key rotation doesn't
require rebuilding or restarting this container.
