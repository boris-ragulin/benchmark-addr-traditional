resource "kubernetes_namespace" "berlioz" {
  metadata {
    generate_name = "berlioz-"
    labels = {
      istio-injection = "enabled"
    }
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name = "app"
    namespace = kubernetes_namespace.berlioz.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app"
      }
    }
    template {
      metadata {
        labels = {
          app = "app"
        }
      }
      spec {
        init_container {
          name = "initdb"
          image = "arey/mysql-client"
          command = ["/bin/sh", "-c"]
          args = ["mysql -h$(MYSQL_HOST) -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) < /dump/init.sql"]

          volume_mount {
            mount_path = "/dump"
            name = "dump"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.sql_conn.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.mysql_password.metadata[0].name
            }
          }
        }

        container {
          name = "app"
          image = var.app_image

          port {
            container_port = 4000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.sql_conn.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.mysql_password.metadata[0].name
            }
          }
        }

        volume {
          name = "dump"
          config_map {
            name = kubernetes_config_map.sql_dump.metadata[0].name
            items {
              key = "init.sql"
              path = "init.sql"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "web" {
  metadata {
    name = "web"
    namespace = kubernetes_namespace.berlioz.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "web"
      }
    }
    template {
      metadata {
        labels = {
          app = "web"
        }
      }
      spec {
        container {
          name = "web"
          image = var.web_image

          port {
            container_port = 3000
          }

          env {
            name = "APP_HOST"
            value = "${kubernetes_service.app.metadata[0].name}.${kubernetes_namespace.berlioz.metadata[0].name}.svc.cluster.local"
          }

          env {
            name = "APP_PORT"
            value = kubernetes_service.app.spec[0].port[0].port
          }
        }
      }
    }
  }
}
