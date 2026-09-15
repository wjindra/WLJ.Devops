# Project context (legacy)

> **Retired.** This describes the original single-VM Docker host setup, which
> is being torn down in favor of the `qa-pipeline` / `qa-web` / `qa-db`
> architecture in the repo root [`README.md`](../README.md). Kept here for
> reference during the transition.

Working notes for reviewers and future changes. Keep this current when intent
or open questions change.

## What this repo is

Host-side provisioning helpers for standing up a local Docker host inside a
Multipass VM, plus the networking and tooling the host needs to drive it.
There is no application code and nothing to build.

## Conventions

- Keep **host-side** and **VM-side** concerns in separate files.
- `*.sh` scripts run on the Ubuntu host; `*.yaml` cloud-init files run in the VM.
- Network address, gateway, DNS, and interface name (`enp2s0`) are hard-coded to
  the author's LAN. Anyone reusing this must edit them.

## Terraform

- Installed on the **host** (not the VM) via `install-terraform.sh`, using
  HashiCorp's official APT repo.
- Intent: drive Multipass / Docker / cloud infra as code from the host.

## docker-init.yaml — status

- The author has run this file successfully in a prior provisioning; treat it as
  **known-working**, not broken.
- `$KEYFILE` and `$RELEASE` in the `apt.sources` block are cloud-init apt-module
  template variables and are substituted at runtime — not a bug.
- Open question for next review: the source URL is `https://docker.com` while
  Docker's documented APT repo is `https://download.docker.com/linux/ubuntu`.
  Confirm on the next VM launch which one actually resolves; update the file only
  if the launch fails.
- Not yet wired into `multipass-launch.sh` (which currently uses Canonical's
  upstream `cloud-init-docker.yaml` from `main`). Switching to this local file
  would remove the upstream-drift risk.

## Open items

- [ ] Verify `docker-init.yaml` end to end on a fresh `multipass launch`, then
      decide whether to point `multipass-launch.sh` at it.
- [ ] Pin the upstream cloud-init reference to a tag/commit if we keep using it.
