output "qa_pipeline_ips" {
  description = "All IPv4 addresses of qa-pipeline (NAT + bridged)"
  value       = multipass_instance.qa_pipeline.ipv4
}

output "qa_web_ips" {
  description = "All IPv4 addresses of qa-web (NAT + bridged)"
  value       = multipass_instance.qa_web.ipv4
}

output "qa_db_ips" {
  description = "All IPv4 addresses of qa-db (NAT + bridged)"
  value       = multipass_instance.qa_db.ipv4
}

# Terraform has no built-in cidrcontains (checked: not available in this
# version), so this matches against the actual enp2s0/br-enp2s0 LAN prefix
# instead of excluding Multipass's NAT range. Still a /24 assumption, not
# true CIDR containment, but it identifies the real LAN interface rather
# than guessing from list order.
#
# TODO(ansible-pr): reconsider dropping these *_lan_ip outputs and lan_cidr
# entirely once Ansible inventory generation exists. Ansible's ipaddr
# filter (ansible.netcommon/netaddr) does real CIDR containment, so
# picking the LAN address out of the raw *_ips list belongs there instead
# of being duplicated here.
locals {
  lan_prefix = join(".", slice(split(".", cidrhost(var.lan_cidr, 0)), 0, 3))
}

output "qa_pipeline_lan_ip" {
  description = "Bridged (LAN) IPv4 address of qa-pipeline"
  value       = [for ip in multipass_instance.qa_pipeline.ipv4 : ip if startswith(ip, "${local.lan_prefix}.")][0]
}

output "qa_web_lan_ip" {
  description = "Bridged (LAN) IPv4 address of qa-web"
  value       = [for ip in multipass_instance.qa_web.ipv4 : ip if startswith(ip, "${local.lan_prefix}.")][0]
}

output "qa_db_lan_ip" {
  description = "Bridged (LAN) IPv4 address of qa-db"
  value       = [for ip in multipass_instance.qa_db.ipv4 : ip if startswith(ip, "${local.lan_prefix}.")][0]
}
