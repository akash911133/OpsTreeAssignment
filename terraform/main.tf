# ConfigMap for greeting
resource "kubernetes_config_map" "app_config" {
  metadata {
    name = "app-config"
  }

  data = {
    greeting = "Hello from DevOps Interview!"
  }
}

# Deployment for Node.js app
resource "kubernetes_deployment" "hello_app" {
  metadata {
    name = "hello-app"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "hello-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-app"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        container {
          image = "hello-app:latest"
          name  = "hello-app"

          port {
            container_port = 8080
          }

          env {
            name = "GREETING"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "greeting"
              }
            }
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
        }
      }
    }
  }
}

# Service for app
resource "kubernetes_service" "hello_service" {
  metadata {
    name = "hello-service"
  }

  spec {
    selector = {
      app = "hello-app"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

# HPA for app
resource "kubernetes_horizontal_pod_autoscaler" "app_hpa" {
  metadata {
    name = "hello-app-hpa"
  }

  spec {
    max_replicas = 6
    min_replicas = 3

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.hello_app.metadata[0].name
    }

    target_cpu_utilization_percentage = 70
  }
}

# Prometheus and Grafana via Helm (kube-prometheus-stack includes operator, Prometheus, Grafana with default dashboards for CPU/memory on pods/nodes)
resource "helm_release" "prometheus" {
  name       = "prom"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "default"  # For simplicity

  set =[
    {
    name  = "grafana.service.type"
    value = "LoadBalancer"
    }
  ]

  # Defaults include dashboards for cluster nodes and pod CPU/memory
}

# ServiceMonitor for app (depends on Prometheus Operator CRDs)
resource "kubernetes_manifest" "app_servicemonitor" {
  depends_on = [helm_release.prometheus]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "hello-app-monitor"
      namespace = "default"
      labels = {
        release = "prom"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "hello-app"
        }
      }
      endpoints = [
        {
          port = "http"
          path = "/metrics"
        }
      ]
    }
  }
}

# Elasticsearch via Helm (single-node)
resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  namespace  = "default"

  set = [ 
    {
        name  = "replicas"
        value = "1"
    },
    {
        name  = "minimumMasterNodes"
        value = "1"
    },
    {
        name  = "discovery.type"
        value = "single-node"
    }
  ]
}

# Kibana via Helm
resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  namespace  = "default"

  set = [
    {
    name  = "elasticsearchHosts"
    value = "http://elasticsearch-master.default.svc.cluster.local:9200"
    },
    {  
    name  = "service.type"
    value = "LoadBalancer"
    }
  ]

  depends_on = [helm_release.elasticsearch]
}

# Fluentd DaemonSet via Helm
resource "helm_release" "fluentd" {
  name       = "fluentd"
  repository = "https://kiwigrid.github.io"
  chart      = "fluentd-elasticsearch"
  namespace  = "default"

  set = [
    {
        name  = "elasticsearch.host"
        value = "elasticsearch-master.default.svc.cluster.local"
    },
    {
        name  = "elasticsearch.port"
        value = "9200"
    }
  ]

  depends_on = [helm_release.elasticsearch]
}