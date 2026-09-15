multipass launch 24.04 \
  --name docker \
  --cpus 2 \
  --memory 2G \
  --disk 20G \
  --network enp2s0 \
  --cloud-init https://raw.githubusercontent.com/canonical/multipass/refs/heads/main/data/cloud-init-yaml/cloud-init-docker.yaml
