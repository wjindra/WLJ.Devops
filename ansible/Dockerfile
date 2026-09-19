# Ansible container-job image. Referenced by azure-pipelines.yml via
# `resources.containers` / `container:` so each pipeline job's steps run
# inside this image, launched fresh per run via Agent #1's
# Docker-outside-of-Docker access to the host daemon. Built once locally --
# no registry needed for a single-host setup, since Azure Pipelines'
# container-job feature just needs the tagged image present locally:
#
#   docker build -t wlj-ansible:local ansible/
#
# Alternative base if alpine/ansible ever stops being pullable/maintained:
# cytopia/ansible:latest-tools (also Alpine-based, nightly-built, bundles
# git/jq/ssh) is a drop-in swap for the FROM line below.

FROM alpine/ansible:latest

RUN apk add --no-cache openssh-client

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml
