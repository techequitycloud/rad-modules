# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = var.configure_environment ? google_cloud_run_v2_service.app_service[0].name : ""
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = var.configure_environment ? google_cloud_run_v2_service.app_service[0].uri : ""
}

output "db_internal_ip" {
  description = "Internal IP of the database instance"
  value       = local.db_internal_ip
}

output "nfs_internal_ip" {
  description = "Internal IP of the NFS server"
  value       = local.nfs_internal_ip
}
