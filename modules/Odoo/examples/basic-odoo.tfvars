resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "basic-odoo"
deployment_region    = "us-central1"

application_module   = "odoo"
application_name     = "odoo"

# GCS Bucket for Odoo Custom Addons
gcs_buckets = {
  "odoo-addons" = {
    name          = "qwiklabs-03-5421a1d20b10-odoo-addons"
    location      = "US"
    storage_class = "STANDARD"
    versioning    = false
    lifecycle_rules = []
  }
}