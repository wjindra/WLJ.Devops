# Generates a dedicated SSH keypair for Ansible and gets its public key onto
# each VM's `ubuntu` user, without touching cloud_init_file and without
# risking multipassd's own SSH channel (`multipass exec`/`transfer`/`shell`).
#
# multipass_instance has no ssh-key attribute; instead we upload the pubkey
# via multipass_file_upload (maps to `multipass transfer`, SSH-independent),
# then append it to authorized_keys via `multipass exec` (also
# SSH-independent), guarded by grep so repeated applies stay idempotent and
# any existing keys -- including multipassd's own -- are never overwritten.

resource "tls_private_key" "ansible" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ansible_private_key" {
  content         = tls_private_key.ansible.private_key_openssh
  filename        = pathexpand(var.ansible_private_key_path)
  file_permission = "0600"
}

resource "local_file" "ansible_public_key" {
  content         = tls_private_key.ansible.public_key_openssh
  filename        = "${pathexpand(var.ansible_private_key_path)}.pub"
  file_permission = "0644"
}

locals {
  ssh_bootstrap_instances = {
    qa_pipeline = multipass_instance.qa_pipeline.name
    qa_web      = multipass_instance.qa_web.name
    qa_db       = multipass_instance.qa_db.name
  }
}

resource "multipass_file_upload" "ansible_key" {
  for_each = local.ssh_bootstrap_instances

  instance       = each.value
  destination    = var.ansible_pubkey_scratch_path
  content        = tls_private_key.ansible.public_key_openssh
  create_parents = true
}

resource "terraform_data" "ansible_authorized_key" {
  for_each = local.ssh_bootstrap_instances

  input = tls_private_key.ansible.public_key_fingerprint_sha256

  provisioner "local-exec" {
    command = <<-EOT
      multipass exec ${each.value} -- bash -c '
        mkdir -p /home/ubuntu/.ssh
        chmod 700 /home/ubuntu/.ssh
        touch /home/ubuntu/.ssh/authorized_keys
        grep -qxFf ${var.ansible_pubkey_scratch_path} /home/ubuntu/.ssh/authorized_keys \
          || cat ${var.ansible_pubkey_scratch_path} >> /home/ubuntu/.ssh/authorized_keys
        chmod 600 /home/ubuntu/.ssh/authorized_keys
        chown -R ubuntu:ubuntu /home/ubuntu/.ssh
      '
    EOT
  }

  depends_on = [multipass_file_upload.ansible_key]
}

output "ansible_private_key_path" {
  description = "Host path of the generated Ansible SSH private key"
  value       = local_sensitive_file.ansible_private_key.filename
}
