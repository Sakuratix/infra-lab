locals {
  name   = "infra-lab-${var.env}"
  labels = { project = "infra-lab", env = var.env, managed_by = "terraform" }
}

# ---------- network ----------
resource "yandex_vpc_network" "this" {
  name   = local.name
  labels = local.labels
}

resource "yandex_vpc_subnet" "this" {
  name           = "${local.name}-${var.zone}"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = ["10.10.0.0/24"]
  labels         = local.labels
}

# ---------- service accounts ----------
resource "yandex_iam_service_account" "k8s" {
  name = "${local.name}-k8s"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s" {
  for_each  = toset(["k8s.clusters.agent", "vpc.publicAdmin", "container-registry.images.puller", "load-balancer.admin"])
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

# ---------- managed kubernetes ----------
resource "yandex_kubernetes_cluster" "this" {
  name       = local.name
  network_id = yandex_vpc_network.this.id

  master {
    version   = var.k8s_version
    public_ip = true
    zonal {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.this.id
    }
    maintenance_policy {
      auto_upgrade = true
      maintenance_window {
        start_time = "02:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.k8s.id
  node_service_account_id = yandex_iam_service_account.k8s.id
  release_channel         = "STABLE"
  labels                  = local.labels

  depends_on = [yandex_resourcemanager_folder_iam_member.k8s]
}

resource "yandex_kubernetes_node_group" "default" {
  cluster_id = yandex_kubernetes_cluster.this.id
  name       = "${local.name}-default"
  version    = var.k8s_version

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = var.node_resources.cores
      memory        = var.node_resources.memory
      core_fraction = var.node_resources.core_fraction
    }
    boot_disk {
      type = "network-ssd"
      size = 64
    }
    network_interface {
      subnet_ids = [yandex_vpc_subnet.this.id]
      nat        = true
    }
    container_runtime {
      type = "containerd"
    }
    scheduling_policy {
      preemptible = var.env != "prod"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }

  labels = local.labels
}

# ---------- managed postgresql ----------
resource "yandex_mdb_postgresql_cluster" "this" {
  name        = local.name
  environment = var.env == "prod" ? "PRODUCTION" : "PRESTABLE"
  network_id  = yandex_vpc_network.this.id
  labels      = local.labels

  config {
    version = 16
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 20
    }
    backup_window_start {
      hours   = 3
      minutes = 0
    }
  }

  host {
    zone      = var.zone
    subnet_id = yandex_vpc_subnet.this.id
  }
}

resource "yandex_mdb_postgresql_user" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.this.id
  name       = "app"
  password   = var.db_password
}

resource "yandex_mdb_postgresql_database" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.this.id
  name       = "app"
  owner      = yandex_mdb_postgresql_user.app.name
}
