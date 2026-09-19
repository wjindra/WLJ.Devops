# WLJ.DevOps

Infrastructure, CI/CD pipelines, and deployment configuration for the WLJ platform. Owned by the platform/infrastructure team. Application domain and business logic lives in the [WLJ.Payments](https://dev.azure.com) repo.

**Canonical repo:** Azure DevOps (`origin`). This repo is also mirrored (public, `master` + active feature branches only) to [github.com/wjindra/WLJ.Devops](https://github.com/wjindra/WLJ.Devops) as a `github` remote, so it can be reviewed from Claude Desktop. Push changes to `origin` first; mirror to `github` as needed.

## Environments

| Environment | Description |
|---|---|
| **Dev** | Local Windows machine — Visual Studio, Docker Desktop, .NET Aspire orchestration |
| **QA** | Ubuntu 24.04 Server on-prem — pipeline deployments, mimics production topology |

QA deployments occur once or twice daily via Azure Pipelines, with additional adhoc deployments as needed.

## Networking

### Local — Dnsmasq
Dnsmasq runs directly on the Ubuntu host (not containerized) and provides DNS resolution for all VMs and local network devices. VMs are referenced by hostname rather than IP:

DNS is deliberately kept off containers: name resolution is on the critical path for everything else on the network, and the host shouldn't depend on the Docker daemon or a container's health to resolve hostnames. Root DNS lives on the root host.

| Hostname | Role |
|---|---|
| `qa-pipeline.local` | Azure Pipelines self-hosted agent |
| `qa-web.local` | Application runtime |
| `qa-db.local` | Database / infrastructure |

### Hybrid Cloud — ZeroTier
ZeroTier creates a flat private network spanning on-prem and any future cloud resources, without the cost of Azure VPN Gateway. All on-prem VMs and future cloud resources join the same ZeroTier network and see each other as local.

**Future cloud resources** may include Azure App Service or Container Apps (stateless, can be shut down when not needed) rather than dedicated VMs, to minimize cost. This is not yet planned.

## Infrastructure Layout

**Host OS:** Ubuntu 24.04 Server (on-prem, static IP via `enp2s0`)

Tools installed directly on host:
- **Claude Code** — agentic coding and orchestration
- **Docker Engine** — ad hoc container runs
- **Dnsmasq** — local DNS for VM hostnames
- **ZeroTier** — hybrid cloud networking
- **Ansible** — VM configuration management, run containerized via Azure Pipelines container jobs (see `agent/` and `ansible/Dockerfile`), launched by the on-host self-hosted ADO agent's Docker-outside-of-Docker access rather than installed directly on bare metal
- **Terraform** — installed directly on the host, not containerized, and not on `qa-pipeline`

Terraform runs directly on the host rather than via container: the `todoroff/multipass` provider (like its predecessor) shells out to the `multipass` CLI, which on this host is a snap-confined binary tightly coupled to `multipassd`'s mount namespace — it doesn't hand off cleanly to a generic Docker container. It also isn't installed on `qa-pipeline`, since that VM is itself one of the things Terraform provisions, which would create a bootstrap dependency on the first `apply`.

```
ZeroTier Network
│
├── Ubuntu 24.04 Host (on-prem, enp2s0)
│   ├── Claude Code
│   ├── Dnsmasq
│   ├── ZeroTier
│   ├── Ansible
│   ├── Terraform
│   │
│   ├── VM: qa-pipeline          -- Azure Pipelines self-hosted agent
│   │     - Docker Engine
│   │     - Azure Pipelines agent
│   │     - Self-hosted Docker registry
│   │
│   ├── VM: qa-web               -- Application runtime
│   │     - Docker Engine
│   │     - App containers
│   │
│   └── VM: qa-db                -- Data / infrastructure
│         - Docker Engine
│         - PostgreSQL container
│         - Future: Redis, messaging, etc.
│
└── Azure (future, minimal spend)
      - App Service or Container Apps (stateless, stoppable)
      - Joins ZeroTier network
```

All VMs are bridged via `enp2s0` and have their own LAN IP. See `docs/multipass-bridged-network-setup.md` for the full network setup reference.

## Repository Structure

```
WLJ.DevOps/
├── README.md
├── docs/
│   └── multipass-bridged-network-setup.md
├── terraform/
│   ├── main.tf                  -- Multipass VM provisioning
│   ├── variables.tf             -- input variables
│   ├── outputs.tf               -- VM IPv4 addresses
│   ├── apply.sh                 -- init/plan/apply on the host
│   └── destroy.sh               -- terraform destroy on the host
└── ansible/
    ├── inventory/
    │   └── qa.ini               -- qa-pipeline, qa-web, qa-db hosts
    ├── playbooks/
    │   ├── pipeline.yml         -- Azure Pipelines agent setup
    │   ├── web.yml              -- app runtime setup
    │   └── db.yml               -- PostgreSQL setup
    └── roles/                   -- reusable role definitions
```

## Pipelines

- **WLJ.Payments** — build, test, push image to self-hosted registry, deploy to `qa-web`
- **WLJ.DevOps** — Ansible provisioning

Pipelines are intentionally separate — infrastructure changes have their own review and approval lifecycle.

## IaC Strategy

| Tool | Responsibility |
|---|---|
| **Terraform** | Provision VMs, manage DNS records, future Azure resources — run manually on the root host, not part of any Azure Pipeline |
| **Ansible** | Configure VMs — Docker, Azure Pipelines agent, PostgreSQL, ZeroTier |

Terraform is kept out of CI for now: it's a solo/learning setup with a single static host, so there's no concurrent-apply race to guard against and no review workflow to gate. It's worth moving into a pipeline later if other people start touching the infra, if state needs remote locking, or if infra changes need to ship alongside app releases.

### Multipass provider — switched to `todoroff/multipass`

The originally used `larstobi/multipass` provider (`~> 1.4`) has no `network`/`bridged` attribute at all, so `multipass_instance` resources always landed on Multipass's default NAT network — not reachable from the LAN, breaking the Dnsmasq/hostname design above. A fix was drafted and submitted upstream ([larstobi/terraform-provider-multipass#30](https://github.com/larstobi/terraform-provider-multipass/pull/30)), confirmed working via a locally patched build, but it's no longer needed for our own use.

Switched to [`todoroff/multipass`](https://registry.terraform.io/providers/todoroff/multipass) instead: a from-scratch (not a fork), actively-versioned provider on the official registry with native `networks {}` block support, an `ipv4` output that's a **list** of all interface addresses (NAT + bridged + any in-VM ones), and `wait_for_cloud_init` (blocks the resource from reporting "created" until cloud-init finishes — avoids Ansible running before Docker etc. is actually installed). No provider patching or `dev_overrides` needed; it installs straight from the registry.

**Maturity caveat:** solo-maintained, created November 2025, 8 stars, no release since `1.7.1` (April 2026) as of this writing — unproven long-term compared to `larstobi/multipass`'s longer track record. If it stalls, PR #30 above is a ready fallback for going back to `larstobi/multipass`.

**Known rough edge:** the `*_lan_ip` outputs in `outputs.tf` pick the LAN address out of the `ipv4` list by excluding Multipass's known NAT prefix and taking whatever's left first — it works because of the order `multipass info` happens to list addresses in, not because it actually identifies the LAN interface. Flagged inline in `outputs.tf`; revisit if it ever picks the wrong IP.

## Next Steps

- [x] Provision `qa-pipeline`, `qa-web`, `qa-db` via `terraform apply`
- [ ] Install Dnsmasq on Ubuntu host, configure VM hostnames
- [ ] Install ZeroTier on Ubuntu host and VMs
- [x] Write Ansible playbooks for each VM role
- [x] Draft `azure-pipelines.yml` for `WLJ.DevOps` — Ansible provisioning
- [ ] Run the Terraform SSH bootstrap (`terraform/ssh_bootstrap.tf`) so Ansible can reach the VMs
- [ ] Build and register the on-host ADO agent (`agent/`) and the Ansible container-job image (`ansible/Dockerfile`) — see `agent/README.md`
- [ ] Complete manual ADO setup (agent pools, PAT, Secure File, variable group) — see `docs/ansible-provisioning-plan.md`
- [ ] Run `ansible/playbooks/pipeline.yml` — installs the Azure Pipelines self-hosted agent + self-hosted Docker registry on `qa-pipeline`
- [ ] Run `ansible/playbooks/db.yml` and `web.yml` against `qa-db` and `qa-web`
- [ ] Draft `azure-pipelines.yml` for `WLJ.Payments` — build, push, deploy to `qa-web`
