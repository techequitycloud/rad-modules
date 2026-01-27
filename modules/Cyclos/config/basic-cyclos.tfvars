resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "basic"
deployment_region    = "us-central1"
container_image_source = "prebuilt"

application_module   = "cyclos"
application_name     = "cyclos"

# GCS Volume mapping for Cyclos config
gcs_volumes = [
  {
    name          = "cyclos-config"
    bucket_name   = ""
    mount_path    = "/mnt"
    read_only     = false
    mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
  }
]