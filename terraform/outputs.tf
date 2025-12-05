# ============================================
# terraform/outputs.tf
# ============================================

output "instance_id" {
  description = "Instance ID"
  value       = openstack_compute_instance_v2.card_game.id
}

output "instance_name" {
  description = "Instance name"
  value       = openstack_compute_instance_v2.card_game.name
}

output "instance_ip" {
  description = "Instance IP address"
  value       = openstack_compute_instance_v2.card_game.access_ip_v4
}

output "private_ip" {
  description = "Private IP address"
  value       = openstack_compute_instance_v2.card_game.access_ip_v4
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/card-game-key ubuntu@${openstack_compute_instance_v2.card_game.access_ip_v4}"
}

output "app_url" {
  description = "Application URL"
  value       = "http://${openstack_compute_instance_v2.card_game.access_ip_v4}"
}

output "api_url" {
  description = "API URL"
  value       = "http://${openstack_compute_instance_v2.card_game.access_ip_v4}:5000"
}