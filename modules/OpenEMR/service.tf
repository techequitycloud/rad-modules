resource "google_cloud_run_v2_service" "app_service" {
  for_each            = var.configure_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location            = each.key
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.application_image.repository_id}/${var.application_name}:${var.application_version}"
      
      ports {
        container_port = 80
        name          = "http1"
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }

      # FIXED: Better startup probe configuration
      startup_probe {
        initial_delay_seconds = 30      # Start checking after 30 seconds
        timeout_seconds       = 10      # 10 seconds per check
        period_seconds        = 10      # Check every 10 seconds
        failure_threshold     = 30      # 30 attempts = 5 minutes total (30 + 10*30 = 330s)
        
        http_get {
          path = "/"                    # Check root path (more reliable)
          port = 80
          http_headers {
            name  = "User-Agent"
            value = "GoogleHC/1.0"
          }
        }
      }

      # FIXED: Better liveness probe
      liveness_probe {
        initial_delay_seconds = 60      # Wait 1 minute after startup
        timeout_seconds       = 5       # 5 seconds per check
        period_seconds        = 30      # Check every 30 seconds
        failure_threshold     = 3       # Fail after 3 attempts
        
        http_get {
          path = "/"                    # Use root path instead of login page
          port = 80
          http_headers {
            name  = "User-Agent"
            value = "GoogleHC/1.0"
          }
        }
      }

      # MySQL/Database Configuration
      env {
        name  = "MYSQL_DATABASE"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name  = "MYSQL_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name = "MYSQL_PASS"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      env {
        name  = "MYSQL_HOST"
        value = local.db_internal_ip
      }

      env {
        name = "MYSQL_ROOT_PASS"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-root-password"
            version = "latest"
          }
        }
      }

      env {
        name  = "MYSQL_PORT"
        value = "3306"
      }

      # OpenEMR Admin Configuration
      env {
        name  = "OE_USER"
        value = "admin"
      }

      env {
        name = "OE_PASS"
        value_source {
          secret_key_ref {
            secret = "openemr-admin-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      # FIXED: Set to "yes" if database is already initialized
      env {
        name = "MANUAL_SETUP"
        value = "yes"  # Changed from "no" to "yes" - skip auto-setup
      }

      # ADDED: Skip auto-setup since we're using import_db job
      env {
        name  = "EMPTY"
        value = ""
      }

      # ADDED: Force production mode
      env {
        name  = "OPENEMR_DOCKER_ENV_TAG"
        value = "production"
      }

      # ADDED: Disable dev mode
      env {
        name  = "EASY_DEV_MODE"
        value = "off"
      }

      env {
        name  = "EASY_DEV_MODE_NEW"
        value = "off"
      }

      # ADDED: Force no build mode (skip setup scripts)
      env {
        name  = "FORCE_NO_BUILD_MODE"
        value = "1"
      }

      # PHP Configuration Overrides
      env {
        name  = "PHP_MEMORY_LIMIT"
        value = "2048M"
      }

      env {
        name  = "PHP_MAX_EXECUTION_TIME"
        value = "300"
      }

      env {
        name  = "PHP_MAX_INPUT_TIME"
        value = "300"
      }

      env {
        name  = "PHP_POST_MAX_SIZE"
        value = "128M"
      }

      env {
        name  = "PHP_UPLOAD_MAX_FILESIZE"
        value = "128M"
      }

      env {
        name  = "PHP_MAX_INPUT_VARS"
        value = "3000"
      }

      # Apache Configuration
      env {
        name  = "APACHE_RUN_USER"
        value = "www-data"
      }

      env {
        name  = "APACHE_RUN_GROUP"
        value = "www-data"
      }

      # ADDED: Apache timeout settings
      env {
        name  = "APACHE_TIMEOUT"
        value = "300"
      }

      volume_mounts {
        name       = "nfs-data-volume"
        mount_path = "/var/www/localhost/htdocs/openemr/sites"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/gce-vpc-subnet-${each.key}"
        tags       = ["nfsserver"]
      }
      egress = "PRIVATE_RANGES_ONLY"  # ADDED: Explicit egress setting
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server    = local.nfs_internal_ip
        path      = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        read_only = false  # ADDED: Explicit read_only setting
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_db,
    null_resource.import_nfs,
    null_resource.execute_init_job,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.openemr_admin_password,
    null_resource.build_and_push_application_image
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service_iam" {
  for_each = var.configure_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.app_service[each.key].location
  service  = google_cloud_run_v2_service.app_service[each.key].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}
