# Self-hosted Azure Pipelines agent (Agent #1) + Ansible, built to run as a
# long-lived container on the root host. Drives the WLJ.DevOps pipeline.
#
# Build from the repo root so it can pull in ansible/requirements.yml:
#   docker build -f agent/Dockerfile -t wlj-devops-agent .

FROM ubuntu:24.04

ARG AZP_AGENT_VERSION=4.255.0

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates jq git openssh-client \
      python3 python3-pip \
      libicu74 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages ansible-core

COPY ansible/requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml

RUN mkdir /azp && cd /azp \
    && curl -fsSL -o agent.tar.gz \
       "https://vstsagentpackage.azureedge.net/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz" \
    && tar zxf agent.tar.gz && rm agent.tar.gz \
    && ./bin/installdependencies.sh

WORKDIR /azp
COPY agent/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
