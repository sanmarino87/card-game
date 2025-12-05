# ============================================
# terraform/main.tf
# ============================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  cloud = var.cloud_name
}

# ============================================
# DATA SOURCES
# ============================================

data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

data "openstack_networking_network_v2" "network" {
  name = var.network_name
}

# ============================================
# SECURITY GROUP
# ============================================

resource "openstack_networking_secgroup_v2" "card_game" {
  name        = "${var.app_name}-secgroup"
  description = "Security group for Card Game application"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.card_game.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.card_game.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.card_game.id
}

resource "openstack_networking_secgroup_rule_v2" "api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5000
  port_range_max    = 5000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.card_game.id
}

# ============================================
# COMPUTE INSTANCE
# ============================================

resource "openstack_compute_instance_v2" "card_game" {
  name            = "${var.app_name}-server"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.key_pair
  security_groups = concat([openstack_networking_secgroup_v2.card_game.name], var.security_groups)

  network {
    uuid = data.openstack_networking_network_v2.network.id
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    db_password    = var.db_password
    domain_name    = var.domain_name
    admin_email    = var.admin_email
  })

  metadata = {
    environment = var.environment
    application = var.app_name
  }
}

# ============================================
# FLOATING IP
# ============================================

resource "openstack_networking_floatingip_v2" "card_game" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "card_game" {
  floating_ip = openstack_networking_floatingip_v2.card_game.address
  instance_id = openstack_compute_instance_v2.card_game.id
}