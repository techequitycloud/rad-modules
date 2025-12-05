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

#########################################################################
# External data source to check for existing SQL instance
#########################################################################

data "external" "sql_instance_info" {
  program = ["bash", "${path.module}/scripts/app/get-sqlserver-info.sh", local.project.project_id, "POSTGRES", var.resource_creator_identity]
}

#########################################################################
# Local variables for SQL infrastructure
#########################################################################

locals {
  sql_server_exists = try(data.external.sql_instance_info.result["sql_server_exists"], "")
  db_instance_name = try(data.external.sql_instance_info.result["instance_name"], "")
  db_instance_region = try(data.external.sql_instance_info.result["instance_region"], "")
  database_version = try(data.external.sql_instance_info.result["database_version"], "")
  db_internal_ip = try(data.external.sql_instance_info.result["instance_ip"], "")
  db_root_password = try(data.external.sql_instance_info.result["root_password"], "")
}
