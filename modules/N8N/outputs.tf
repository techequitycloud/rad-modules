# Copyright 2024 Tech Equity Ltd
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

output "app_service_urls" {
  value = { for k, v in google_cloud_run_v2_service.app_service : k => v.uri }
}

output "sql_instance_info" {
  value = {
    instance_exists  = local.sql_server_exists
    database_version = local.database_version
    instance_name    = local.db_instance_name
    instance_region  = local.db_instance_region
    instance_ip      = local.db_internal_ip
  }
}
