#!/usr/bin/env bash
set -euo pipefail

# Standard Microsoft container-agent registration pattern: config.sh once,
# then exec run.sh as PID 1 so SIGTERM cleanly deregisters the agent.

: "${AZP_URL:?AZP_URL is required}"
: "${AZP_TOKEN:?AZP_TOKEN is required}"
: "${AZP_POOL:?AZP_POOL is required}"
AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)}"
AZP_WORK="${AZP_WORK:-_work}"

cd /azp

cleanup() {
  if [ -f .agent ]; then
    echo "Removing agent..."
    ./config.sh remove --unattended --auth pat --token "${AZP_TOKEN}"
  fi
}
trap 'cleanup; exit 0' SIGINT SIGTERM

if [ ! -f .agent ]; then
  ./config.sh --unattended \
    --agent "${AZP_AGENT_NAME}" \
    --url "${AZP_URL}" \
    --auth pat \
    --token "${AZP_TOKEN}" \
    --pool "${AZP_POOL}" \
    --work "${AZP_WORK}" \
    --replace \
    --acceptTeeEula
fi

./run.sh &
wait $!
