check "enable_config_management_dependencies" {
  assert {
    condition     = var.enable_config_management ? var.enable_cloud_service_mesh : true
    error_message = "Anthos Config Management requires Cloud Service Mesh to be enabled. Please set enable_cloud_service_mesh to true."
  }
}
