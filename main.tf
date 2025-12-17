

module "persistent_volumes" {
  source = "./modules/longhorn"

  pv_map = {
    keycloak = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "keycloak" }
      access_modes       = ["ReadWriteOnce"]
    }

    prometheus = {
      disk_size_gb       = 100
      storage_class_name = "cosmotech-retain"
      labels             = { app = "prometheus" }
      access_modes       = ["ReadWriteOnce"]
    }

    grafana = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "grafana" }
      access_modes       = ["ReadWriteOnce"]
    }

    loki = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "loki" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-registry = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-jobservice = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-chartmuseum = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-trivy = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-postgresql = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }

    harbor-redis = {
      disk_size_gb       = 50
      storage_class_name = "cosmotech-retain"
      labels             = { app = "harbor" }
      access_modes       = ["ReadWriteOnce"]
    }
  }
}