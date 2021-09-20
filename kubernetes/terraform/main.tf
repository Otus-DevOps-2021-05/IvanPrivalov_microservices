terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.60.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

data "yandex_compute_image" "ubuntu-image" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance" "k8s" {
  name  = "k8s-${count.index}"
  count = var.count_instance

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      #image_id = var.image_id
      image_id = data.yandex_compute_image.ubuntu-image.image_id
      size     = 40
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

locals {
  names = yandex_compute_instance.k8s.*.name
  ips   = yandex_compute_instance.k8s.*.network_interface.0.nat_ip_address
}

# Invetrory for ansible and run playbook
resource "local_file" "inventory" {
  content = templatefile("inventory.tpl",
    {
      #k8s_hosts = yandex_compute_instance.k8s.*.network_interface.0.nat_ip_address
      names = local.names,
      addrs = local.ips,
    }
  )
  filename = "../ansible/inventory.ini"

  provisioner "local-exec" {
    command     = "ansible-playbook k8s_playbook.yml"
    working_dir = "../ansible"
  }
}
