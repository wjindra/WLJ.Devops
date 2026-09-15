# WLJ.Devops (legacy)

> **Retired.** This single-VM Docker host setup is being torn down in favor of
> the `qa-pipeline` / `qa-web` / `qa-db` architecture described in the repo
> root [`README.md`](../README.md). Kept here for reference during the
> transition.

Provisioning scripts for standing up a local Docker host inside a
[Multipass](https://multipass.run/) VM, plus the host-side networking and
tooling needed to drive it.

## Contents

| File                   | Runs on | Purpose                                                                                 |
| ---------------------- | ------- | -------------------------------------------------------------------------------------- |
| `create-enp2s0.sh`     | Host    | Recreate the `enp2s0` NetworkManager connection with a static IP (`192.168.0.100/24`). |
| `install-terraform.sh` | Host    | Install Terraform from HashiCorp's official APT repository.                            |
| `multipass-launch.sh`  | Host    | Launch an Ubuntu 24.04 VM named `docker`, bridged to `enp2s0`, provisioned via cloud-init. |
| `docker-init.yaml`     | VM      | Local `#cloud-config` alternative that installs Docker Engine + Compose. See notes below. |

## Prerequisites

- Ubuntu host with NetworkManager (`nmcli`)
- [`multipass`](https://multipass.run/install) installed on the host
- A wired interface named `enp2s0` (adjust the scripts if yours differs)
- `sudo` privileges

## Getting started

```bash
# 1. Configure the host's wired interface with a static IP
./create-enp2s0.sh

# 2. Install Terraform on the host
./install-terraform.sh

# 3. Launch the Docker VM
./multipass-launch.sh
```

Once the VM is up:

```bash
multipass shell docker
docker run hello-world
```

## Notes

- `multipass-launch.sh` currently provisions the VM with Canonical's upstream
  [`cloud-init-docker.yaml`](https://github.com/canonical/multipass/blob/main/data/cloud-init-yaml/cloud-init-docker.yaml)
  pulled from `main`, so the provisioning can drift as that file changes.
- `docker-init.yaml` is a local alternative to that upstream file. It has been
  used successfully before but is not yet wired into `multipass-launch.sh`. See
  [`CONTEXT.md`](CONTEXT.md) for its status and the open verification item.
- `create-enp2s0.sh` deletes and recreates the `enp2s0` connection. The static
  address, gateway, and DNS servers are hard-coded — edit them to match your
  network.

## Build and test

There is nothing to build. To sanity-check the shell scripts:

```bash
shellcheck ./*.sh
```

## Contribute

Branch from `master`, make your change, and open a pull request. Keep host-side
and VM-side concerns in separate scripts, and note in this README which side a
new script runs on.
