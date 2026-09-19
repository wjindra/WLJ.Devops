# Self-hosted Azure Pipelines agent (Agent #1), run as a long-lived
# container on the root host. Stays a plain agent -- Ansible is never
# installed in this image. The WLJ.DevOps pipeline instead uses Azure
# Pipelines' native container-job feature to run each job's steps inside
# ansible/Dockerfile's image (see azure-pipelines.yml), so this agent only
# needs the Docker CLI (Docker-outside-of-Docker: mount the host's
# /var/run/docker.sock at `docker run` time) to launch those container jobs.
#
# Build: docker build -t wlj-devops-agent agent/

FROM ubuntu:24.04

ARG AZP_AGENT_VERSION=4.255.0
ARG DOCKER_CLI_VERSION=27.3.1

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates jq git libicu74 \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI only (no daemon) -- talks to the host daemon via the mounted socket
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
      -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /tmp \
    && mv /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker.tgz /tmp/docker

RUN mkdir /azp && cd /azp \
    && curl -fsSL -o agent.tar.gz \
       "https://vstsagentpackage.azureedge.net/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz" \
    && tar zxf agent.tar.gz && rm agent.tar.gz \
    && ./bin/installdependencies.sh

WORKDIR /azp
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
