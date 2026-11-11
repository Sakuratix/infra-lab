terraform {
  required_version = ">= 1.6"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
}

provider "yandex" {
  # Auth: export YC_TOKEN=$(yc iam create-token)
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}
