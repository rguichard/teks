
resource "kubernetes_namespace" "nvidia_plugin" {
  count = "${var.nvidia_plugin["enabled"] ? 1 : 0 }"

  metadata {
    annotations {
      "iam.amazonaws.com/permitted" = ".*"
    }

    name = "${var.nvidia_plugin["namespace"]}"
  }
}

resource "kubernetes_daemonset" "nvidia-device-plugin-daemonset" {
  count = "${var.nvidia_plugin["enabled"] ? 1 : 0 }"
  metadata {
    name = "nvidia-device-plugin-daemonset"
    namespace = "${var.nvidia_plugin["namespace"]}"
  }
  spec {
    selector {
      match_labels {
        gpu_node = "true"
      }
    }
    template {
      metadata {
        namespace = "${var.nvidia_plugin["namespace"]}"
        annotations {
          scheduler.alpha.kubernetes.io/critical-pod = ""
        }
        labels {
          name = "nvidia-device-plugin-ds"
        }
      }

      spec {
        tolerations {
          key = "CriticalAddonsOnly"
          operator = "Exists"
        }
        container {
          image = "nvidia/k8s-device-plugin:${var.kubernetes_version}"
          name  = "nvidia-device-plugin-ctr"
          volume_mount {
            name = "device-plugin"
            mount_path = "/var/lib/kubelet/device-plugins"
          }
        }
        volume {
          name = "device-plugin"
          host_path = "/var/lib/kubelet/device-plugins"
        }
      }
    }
  }
}

