variable "cloud_id" { type = string }
variable "folder_id" { type = string }

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "k8s_version" {
  type    = string
  default = "1.30"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_resources" {
  type    = object({ cores = number, memory = number, core_fraction = number })
  default = { cores = 2, memory = 4, core_fraction = 50 }
}

variable "db_password" {
  type      = string
  sensitive = true
}
