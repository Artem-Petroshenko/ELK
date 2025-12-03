terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.50.0"
    }
  }
  required_version = ">= 1.3.0"
}

# Провайдер OpenStack
provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password
  region      = var.region
}

# ----- SSH keypair для доступа к ВМ -----

resource "openstack_compute_keypair_v2" "elk_key" {
  name       = "elk-key"
  public_key = var.public_ssh_key
}

# ----- ВМ под ELK / API -----

resource "openstack_compute_instance_v2" "elk_vm" {
  name        = "elk-vm"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.elk_key.name

  network {
    name = var.network_name   # sutdents-net
  }

  # при необходимости можно добавить security_groups
  # security_groups = ["default"]
}
