resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "basic-odoo"
deployment_region    = "us-central1"
container_image_source = "prebuilt"

application_module   = "odoo"
application_name     = "odoo"

# GCS Volume mapping for Odoo Custom Addons
gcs_volumes = [
  {
    name          = "odoo-addons"
    bucket_name   = ""
    mount_path    = "/mnt/extra-addons"
    read_only     = false
    mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
  }
]