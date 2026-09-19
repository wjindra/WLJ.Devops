#!/usr/bin/env bash
# bootstrap-host.sh
# One-time host setup: Multipass, Docker, Terraform.
# Run as a user with sudo access BEFORE running terraform/apply.sh.
# Safe to re-run (all steps are guarded).

set -euo pipefail

BRIDGE_IFACE="enp2s0"

info()  { echo "==> $*"; }
check() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# 1. Multipass
# ---------------------------------------------------------------------------
info "Installing Multipass..."
if check multipass; then
  info "  Already installed — skipping."
else
  sudo snap install multipass
fi

info "Configuring bridged network (${BRIDGE_IFACE})..."
CURRENT_BRIDGE=$(multipass get local.bridged-network 2>/dev/null || echo "")
if [[ "$CURRENT_BRIDGE" == "$BRIDGE_IFACE" ]]; then
  info "  Already set to ${BRIDGE_IFACE} — skipping."
else
  multipass set local.bridged-network="${BRIDGE_IFACE}"
  info "  Set local.bridged-network=${BRIDGE_IFACE}"
fi

# ---------------------------------------------------------------------------
# 2. Docker
# ---------------------------------------------------------------------------
info "Installing Docker..."
if check docker; then
  info "  Already installed — skipping."
else
  sudo apt-get update -qq
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  info "  Docker installed. Group membership change requires re-login to take effect."
fi

# ---------------------------------------------------------------------------
# 3. Terraform
# ---------------------------------------------------------------------------
info "Installing Terraform..."
if check terraform; then
  info "  Already installed — skipping."
else
  sudo apt-get update -qq
  sudo apt-get install -y gnupg software-properties-common
  wget -O- https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y terraform
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "Bootstrap complete."
echo ""
echo "  Next steps:"
echo "    1. Re-login if Docker was just installed (group membership)"
echo "    2. cd terraform && ./apply.sh"
echo "    3. Trigger the WLJ.DevOps pipeline (Ansible handles the rest)"
