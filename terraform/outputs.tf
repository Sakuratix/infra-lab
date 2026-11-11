output "cluster_id" {
  value = yandex_kubernetes_cluster.this.id
}

output "kubeconfig_command" {
  value = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.this.id} --external"
}

output "postgres_host" {
  value = "c-${yandex_mdb_postgresql_cluster.this.id}.rw.mdb.yandexcloud.net"
}
