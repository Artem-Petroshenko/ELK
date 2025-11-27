terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password
  region      = var.region
}

resource "openstack_networking_network_v2" "elk_net" {
  name = "elk-net"
}

resource "openstack_networking_subnet_v2" "elk_subnet" {
  name       = "elk-subnet"
  network_id = openstack_networking_network_v2.elk_net.id
  cidr       = "10.10.0.0/24"
  ip_version = 4
}

resource "openstack_networking_secgroup_v2" "elk_sg" {
  name        = "elk-sg"
  description = "Security group for ELK"

  // SSH
  rule {
    direction        = "ingress"
    ethertype        = "IPv4"
    protocol         = "tcp"
    port_range_min   = 22
    port_range_max   = 22
    remote_ip_prefix = "0.0.0.0/0"
  }

  // Kibana (5601)
  rule {
    direction        = "ingress"
    ethertype        = "IPv4"
    protocol         = "tcp"
    port_range_min   = 5601
    port_range_max   = 5601
    remote_ip_prefix = "0.0.0.0/0"
  }
}

resource "openstack_compute_keypair_v2" "elk_key" {
  name       = "elk-key"
  public_key = file("id_rsa_elk_tf.pub")
}

resource "openstack_compute_instance_v2" "elk_vm" {
  name        = "elk-vm"
  image_name  = var.image
  flavor_name = var.flavor
  key_pair    = openstack_compute_keypair_v2.elk_key.name

  security_groups = [
    openstack_networking_secgroup_v2.elk_sg.name
  ]

  network {
    uuid = openstack_networking_network_v2.elk_net.id
  }
}

resource "openstack_networking_floatingip_v2" "elk_fip" {
  pool = var.public_net
}

resource "openstack_compute_floatingip_associate_v2" "elk_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.elk_fip.address
  instance_id = openstack_compute_instance_v2.elk_vm.id
}
