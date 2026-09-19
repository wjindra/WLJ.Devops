#!/usr/bin/env bash
set -euo pipefail

# Provisions qa-pipeline, qa-web, qa-db via the Multipass provider.
#
# Runs directly on the host (not containerized): the larstobi/multipass
# provider shells out to the `multipass` CLI, which on this host is a
# snap-confined binary tightly coupled to multipassd's mount namespace.
# That doesn't hand off cleanly to a generic Docker container.

cd "$(dirname "$0")"

terraform init
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan
