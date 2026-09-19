#!/usr/bin/env bash
set -euo pipefail

# Installs Docker on this host from the same source and packages as the
# Multipass VMs' cloud-init (Canonical's upstream cloud-init-docker.yaml):
# Docker's official APT repo, docker-ce + docker-ce-cli + docker-compose +
# containerd.io. No version is pinned in the VM cloud-init either, so this
# tracks whatever's current in that repo, same as the VMs get at launch.

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli docker-compose containerd.io

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
