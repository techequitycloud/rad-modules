locals {
  # Cyclos uses PGSimpleDataSource with explicit portNumber=5432 in cyclos.properties
  # This requires TCP connection (IP address), not Unix sockets.
  # The Cloud SQL Auth Proxy sidecar is not needed when using private IP via VPC connector.
  cyclos_env_vars = var.application_module == "cyclos" ? {
    DB_HOST = local.db_internal_ip
  } : {}

  cyclos_secret_env_vars = {}

  cyclos_storage_buckets = []
}
