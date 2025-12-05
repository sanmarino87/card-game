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
  description = "Floating IP address"
  value       = openstack_networking_floatingip_v2.card_game.address
}

output "private_ip" {
  description = "Private IP address"
  value       = openstack_compute_instance_v2.card_game.access_ip_v4
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/card-game-key ubuntu@${openstack_networking_floatingip_v2.card_game.address}"
}

output "app_url" {
  description = "Application URL"
  value       = "http://${openstack_networking_floatingip_v2.card_game.address}"
}

output "api_url" {
  description = "API URL"
  value       = "http://${openstack_networking_floatingip_v2.card_game.address}:5000"
}