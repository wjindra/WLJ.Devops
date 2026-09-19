output "qa_pipeline_ip" {
  description = "IPv4 address of qa-pipeline"
  value       = multipass_instance.qa_pipeline.ipv4
}

output "qa_web_ip" {
  description = "IPv4 address of qa-web"
  value       = multipass_instance.qa_web.ipv4
}

output "qa_db_ip" {
  description = "IPv4 address of qa-db"
  value       = multipass_instance.qa_db.ipv4
}
