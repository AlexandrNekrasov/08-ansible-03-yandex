terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">=1.12.0"
}

provider "yandex" {
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a"
  service_account_key_file = file("/home/alex/.ssh/authorized_key.json")
}

# ===== Переменные =====

variable "cloud_id" {
  type    = string
  default = "b1gs228dc2uprpesu6bl"
}

variable "folder_id" {
  type    = string
  default = "b1g6rtd8d4un95vmpsql"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHe/9oSYiHDQ4E20wpTnRZNwEVstGSbp4czSciHMgiQw alarmid@gmail.com"
}

# ===== Образ =====

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# ===== Сеть =====

resource "yandex_vpc_network" "main" {
  name = "ansible-hw03"
}

# Подсеть в зоне a (для vector и lighthouse)
resource "yandex_vpc_subnet" "main_a" {
  name           = "ansible-hw03-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

# Подсеть в зоне d (для clickhouse)
resource "yandex_vpc_subnet" "main_d" {
  name           = "ansible-hw03-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.3.0/24"]
}

# ===== ВМ: ClickHouse (зона d) =====

resource "yandex_compute_instance" "clickhouse" {
  name        = "clickhouse-01"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.main_d.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# ===== ВМ: Vector (зона a) =====

resource "yandex_compute_instance" "vector" {
  name        = "vector-01"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.main_a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# ===== ВМ: Lighthouse (зона a) =====

resource "yandex_compute_instance" "lighthouse" {
  name        = "lighthouse-01"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.main_a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# ===== Outputs =====

output "instances" {
  value = {
    clickhouse = yandex_compute_instance.clickhouse.network_interface[0].nat_ip_address
    vector     = yandex_compute_instance.vector.network_interface[0].nat_ip_address
    lighthouse = yandex_compute_instance.lighthouse.network_interface[0].nat_ip_address
  }
  description = "External IPs of all VMs"
}
