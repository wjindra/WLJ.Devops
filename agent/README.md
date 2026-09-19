# Agent #1 — on-host self-hosted ADO agent

Dockerized Azure Pipelines self-hosted agent that runs the `WLJ.DevOps`
pipeline (Ansible provisioning) from the root host. It's a plain agent --
it never has Ansible installed in its own image. Its first successful
pipeline run installs Agent #2 (the Azure Pipelines agent on
`qa-pipeline`) via `ansible/playbooks/pipeline.yml`.

## Build

```bash
docker build -t wlj-devops-agent agent/
```

## One-time registration

Requires a registration PAT scoped to `Agent Pools: Read & manage` in the
`onprem-infra` pool (see `docs/ansible-provisioning-plan.md` for the full
manual ADO setup steps). The PAT is only used live at registration time --
it is not baked into the image or stored in the container.

The host's Docker socket is mounted in (`-v /var/run/docker.sock:...`) so
this agent can launch Azure Pipelines *container jobs* -- each pipeline
job's steps actually run inside the separate `ansible` image (see
`ansible/Dockerfile`), not inside this agent container itself.

```bash
docker run -d --name wlj-devops-agent --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e AZP_URL=https://dev.azure.com/<org> \
  -e AZP_TOKEN=<registration PAT> \
  -e AZP_POOL=onprem-infra \
  -e AZP_AGENT_NAME=onprem-agent-1 \
  wlj-devops-agent
```

## Ansible container image

Build once, locally, before the first pipeline run (no registry needed for
a single-host setup -- Azure Pipelines' container-job feature just needs
the tagged image present in the host's local Docker cache):

```bash
docker build -t wlj-ansible:local ansible/
```

`azure-pipelines.yml` references this exact tag (`wlj-ansible:local`) via
`resources.containers`. Rebuild it whenever `ansible/requirements.yml`
changes.

The SSH private key used by Ansible inside pipeline jobs is not baked into
either image -- it's downloaded fresh per pipeline run via an ADO Secure
File step (see `/azure-pipelines.yml`), so key rotation doesn't require
rebuilding or restarting anything.
