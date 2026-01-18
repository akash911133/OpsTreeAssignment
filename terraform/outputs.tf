output "app_url_command" {
  value = "minikube service hello-service --url"
  description = "Run this command to get the app URL"
}

output "grafana_url_command" {
  value = "minikube service prom-grafana --url"
  description = "Run this command to get the Grafana URL (default admin/prom-operator)"
}

output "kibana_url_command" {
  value = "minikube service kibana-kibana --url"
  description = "Run this command to get the Kibana URL"
}
