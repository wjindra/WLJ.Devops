#!/usr/bin/env bash
set -euo pipefail

# Tears down qa-pipeline, qa-web, qa-db (and anything else in state).
# Runs directly on the host, same as apply.sh.

cd "$(dirname "$0")"

terraform destroy
