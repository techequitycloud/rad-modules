module "cyclos_module" {
  source      = "./modules/cyclos"
}

locals {
  # Aggregate all modules into a single map for easy lookup
  application_modules = {
    cyclos = module.cyclos_module
  }

  # Cyclos uses PGSimpleDataSource with explicit portNumber=5432 in cyclos.properties
  # This requires TCP connection (IP address), not Unix sockets.
  # The Cloud SQL Auth Proxy sidecar is not needed when using private IP via VPC connector.
  module_env_vars = var.application_module == "cyclos" ? {
    DB_HOST = local.db_internal_ip
  } : {}

  module_secret_env_vars = {}

  module_storage_buckets = []
}
