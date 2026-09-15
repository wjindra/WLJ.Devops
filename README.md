# WLJ.DevOps

Infrastructure, CI/CD pipelines, and deployment configuration for the WLJ platform. Owned by the platform/infrastructure team. Application domain and business logic lives in the [WLJ.Payments](https://dev.azure.com) repo.

## Environments

| Environment | Description |
|---|---|
| **Dev** | Local Windows machine — Visual Studio, Docker Desktop, .NET Aspire orchestration |
| **QA** | Ubuntu 24.04 Server on-prem — pipeline deployments, mimics production topology |

QA deployments occur once or twice daily via Azure Pipelines, with additional adhoc deployments as needed.

## Infrastructure Layout

**Host OS:** Ubuntu 24.04 Server (on-prem, static IP via `enp2s0`)

Tools installed directly on host:
- **Claude Code** — agentic coding and orchestration
- **Docker Engine** — ad hoc container runs (e.g. Terraform)

Terraform is intentionally NOT installed directly on the host — it runs via container on `qa-pipeline` as part of the Azure Pipeline, keeping the host clean and the version controlled.

```
Ubuntu 24.04 Host (enp2s0, static IP)
├── Claude Code                  -- agentic coding, orchestration
├── Docker Engine                -- ad hoc container runs (e.g. Terraform)
│
├── VM: qa-pipeline              -- Azure Pipelines self-hosted agent
│     - .NET SDK
│     - Docker CLI
│     - Azure Pipelines agent
│     - Self-hosted Docker registry
│     - Terraform (via container)
│
├── VM: qa-web                   -- Application runtime
│     - Docker Engine
│     - App containers
│
└── VM: qa-db                    -- Data / infrastructure
      - Docker Engine
      - PostgreSQL container
      - Future: Redis, messaging, etc.
```

All VMs are bridged via `enp2s0` and have their own LAN IP.

See `docs/multipass-bridged-network-setup.md` for the full network setup reference.

## Pipelines

- **WLJ.Payments** — build, test, push image to self-hosted registry, deploy to `qa-web`
- **WLJ.DevOps** — Terraform plan/apply, manages VM infrastructure

Pipelines are intentionally separate — infrastructure changes have their own review and approval lifecycle.

## Container Registry

Self-hosted Docker registry running on `qa-pipeline`. Keeps images on-prem, no licensing cost, no pull rate limits.

## Infrastructure as Code

Terraform manages Multipass VM provisioning and future Azure resources. Runs via container on `qa-pipeline` — never installed directly on the host.

## Next Steps

- [ ] Create `WLJ.DevOps` repo in Azure Repos
- [ ] Delete old throwaway Multipass VM
- [ ] Provision `qa-pipeline`, `qa-web`, `qa-db` Multipass VMs (bridged via `enp2s0`)
- [ ] Install Azure Pipelines self-hosted agent on `qa-pipeline` and register with Azure DevOps
- [ ] Install Docker Engine on `qa-pipeline`, `qa-web`, `qa-db`
- [ ] Set up self-hosted Docker registry on `qa-pipeline`
- [ ] Draft `azure-pipelines.yml` for `WLJ.Payments` — build, push, deploy to `qa-web`
- [ ] Draft Terraform definitions for Multipass VM provisioning
