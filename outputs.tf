output "openmetadata_url" {
  description = "HTTP URL restricted to allowed_cidrs."
  value       = local.openmetadata_url
}

output "login_username" {
  description = "Initial OpenMetadata administrator username. Change the default password immediately after first login."
  value       = "admin@open-metadata.org"
}

output "instance_id" {
  description = "EC2 instance ID for AWS Systems Manager access."
  value       = aws_instance.openmetadata.id
}

output "target_group_arn" {
  description = "ALB target group ARN used to inspect target health."
  value       = aws_lb_target_group.openmetadata.arn
}

output "ssm_session_command" {
  description = "Command to open a shell without SSH."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.openmetadata.id}"
}

output "bootstrap_log_command" {
  description = "Run after opening an SSM session to inspect bootstrap progress."
  value       = "sudo tail -n 200 /var/log/openmetadata-bootstrap.log"
}

output "budget_alert_status" {
  description = "Whether email notifications are configured for the account-level $300 monthly budget."
  value       = var.budget_alert_email == null ? "Budget created without email notifications; set budget_alert_email to receive alerts." : "Budget alerts configured for ${var.budget_alert_email}; confirm the AWS subscription email."
}
