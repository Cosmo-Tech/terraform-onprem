locals {
  pv_processed = {
    for name, cfg in var.pv_map : name => merge(
      {
        volume_source_existing = false
        fs_type                = "ext4"
        labels                 = {}
        access_modes           = ["ReadWriteOnce"]
        storage_class_name     = "longhorn"
      },
      cfg,
      {
        final_volume_name = coalesce(try(cfg.volume_name, null), "${name}")
      }
    )
  }
}

resource "kubernetes_manifest" "longhorn_volume" {
  for_each = {
    for name, cfg in local.pv_processed : name => cfg
    if cfg.volume_source_existing == false
  }

  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "Volume"
    metadata = {
      name      = each.value.final_volume_name
      namespace = "longhorn-system"
      labels    = each.value.labels
    }
    spec = {
      size              = tostring(each.value.disk_size_gb * 1024 * 1024 * 1024)
      numberOfReplicas  = 3
      frontend          = "blockdev"
      fromBackup        = ""
      dataLocality      = "disabled"
      accessMode        = "rwo"
    }
  }
}

resource "kubernetes_persistent_volume" "this" {
  for_each = local.pv_processed

  metadata {
    name   = "pv-${each.key}"
    labels = each.value.labels
  }

  spec {
    capacity = {
      storage = "${each.value.disk_size_gb}Gi"
    }

    access_modes       = each.value.access_modes
    storage_class_name = each.value.storage_class_name

    persistent_volume_source {
      csi {
        driver  = "driver.longhorn.io"
        fs_type = each.value.fs_type

        volume_handle = each.value.final_volume_name
      }
    }
  }

  depends_on = [
    kubernetes_manifest.longhorn_volume
  ]
}
