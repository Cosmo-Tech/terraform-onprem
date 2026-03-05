locals {

  # Volumes are renamed with md5 to avoid Longhorn char limits (~40 chars).
  # Longhorn is automatically renaming volumes with automatics ID when this limit is reached.
  # MD5 size is always 32 char.
  # An annotation "longhorn.io/resource-name" is added to allow better lisibility.
  volume_name = "vol-${md5(var.resource)}"
}

resource "kubernetes_manifest" "longhorn_volume" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "Volume"
    metadata = {
      name      = "${local.volume_name}"
      namespace = "longhorn-system"
      annotations = {
        "longhorn.io/resource-name" = "${var.resource}"
      }
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
        volume_handle = "${local.volume_name}"
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
