# 1. Générer le fichier de conf Nginx avec WebDAV
resource "local_file" "nginx_conf" {
  filename = "${path.module}/nginx.conf"
  content  = <<-EOT
    server {
        listen 80; # Tu peux ajouter le SSL ici plus tard
        location / {
            root /var/www/terraform;
            autoindex on;
            
            # WebDAV pour permettre à Terraform d'écrire (PUT/DELETE)
            dav_methods PUT DELETE MKCOL COPY MOVE;
            create_full_put_path on;
            dav_access user:rw group:rw all:r;

            auth_basic "Terraform Remote State";
            auth_basic_user_file /etc/nginx/.htpasswd;
        }
    }
  EOT
}

# 2. Créer le conteneur Nginx
resource "docker_container" "nginx_backend" {
  name  = "cosmotech-states"
  image = "nginx:alpine"
  ports {
    internal = 80
    external = 8080
  }
  volumes {
    host_path      = var.state_path
    container_path = "/var/www/terraform"
  }
  # On injecte la conf et l'auth via des volumes
  volumes {
    host_path      = abspath(local_file.nginx_conf.filename)
    container_path = "/etc/nginx/conf.d/default.conf"
  }
  
  # Note: En prod, génère le .htpasswd proprement avant
  # Ici on simule l'injection rapide
  upload {
    file    = "/etc/nginx/.htpasswd"
    content = "admin:${var.admin_password}" # Attention: format crypté requis normalement
  }
}