resource "kubernetes_manifest" "longhorn_volume" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "Volume"
    metadata = {
      name      = "vol-${var.resource}"
      namespace = "longhorn-system"
    }
    spec = {
      size             = tostring(var.size * 1024 * 1024 * 1024)
      numberOfReplicas = 1
      accessMode       = "rwo"
      dataLocality     = "disabled"
      frontend         = "blockdev"
      fromBackup       = ""
    }
  }
}

resource "kubernetes_persistent_volume" "pv" {
  metadata {
    name = "pv-${var.resource}"
  }

  spec {
    persistent_volume_reclaim_policy = "Retain"
    capacity = {
      storage = "${var.size}Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    persistent_volume_source {
      csi {
        driver        = "driver.longhorn.io"
        fs_type       = "ext4"
        volume_handle = "vol-${var.resource}"
        volume_attributes = {
          numberOfReplicas    = "1"
          staleReplicaTimeout = "30"
          dataLocality        = "disabled"
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.longhorn_volume]
}

resource "kubernetes_persistent_volume_claim" "pvc" {
  metadata {
    namespace = var.namespace
    name      = "pvc-${var.resource}"
  }

  spec {
    access_modes       = kubernetes_persistent_volume.pv.spec[0].access_modes
    storage_class_name = kubernetes_persistent_volume.pv.spec[0].storage_class_name
    volume_name        = kubernetes_persistent_volume.pv.metadata[0].name
    volume_mode        = kubernetes_persistent_volume.pv.spec[0].volume_mode

    resources {
      requests = {
        storage = kubernetes_persistent_volume.pv.spec[0].capacity.storage
      }
    }
  }

  depends_on = [kubernetes_persistent_volume.pv]
}
