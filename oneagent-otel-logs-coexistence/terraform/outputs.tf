output "activegate_public_ip" {
  description = "Public IP of the ActiveGate VM — use this in your DT installer command"
  value       = aws_instance.activegate.public_ip
}

output "activegate_private_ip" {
  description = "Private IP of the ActiveGate VM — use this as the COLLECTOR_ENDPOINT in otel-collector.env"
  value       = aws_instance.activegate.private_ip
}

output "app_vm_public_ip" {
  description = "Public IP of the App VM — use this to SSH in and run curl tests"
  value       = aws_instance.app_vm.public_ip
}

output "app_vm_private_ip" {
  description = "Private IP of the App VM"
  value       = aws_instance.app_vm.private_ip
}

output "private_key_file" {
  description = "Path to the generated SSH private key — use this to SSH into both VMs"
  value       = local_sensitive_file.private_key.filename
}

output "ssh_activegate" {
  description = "SSH command to connect to the ActiveGate VM"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ec2-user@${aws_instance.activegate.public_ip}"
}

output "ssh_app_vm" {
  description = "SSH command to connect to the App VM"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ec2-user@${aws_instance.app_vm.public_ip}"
}

output "otel_collector_endpoint" {
  description = "Value to set for DT_ACTIVEGATE_ENDPOINT in collector/otel-collector.env"
  value       = "https://${aws_instance.activegate.private_ip}:9993/e/<YOUR_ENV_ID>/api/v2/otlp"
}

output "agent_collector_endpoint" {
  description = "Value to set for COLLECTOR_ENDPOINT in agent/otel-agent.env (if collector runs on app-vm itself)"
  value       = "grpc://127.0.0.1:4317"
}
