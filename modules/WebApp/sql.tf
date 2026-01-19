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
  count   = var.database_type != "NONE" ? 1 : 0
  program = ["bash", "${path.module}/scripts/app/get-sqlserver-info.sh", local.project.project_id, var.database_type, local.impersonation_service_account]
}

#########################################################################
# Local variables for SQL infrastructure
#########################################################################

locals {
  sql_server_exists = var.database_type != "NONE" && try(data.external.sql_instance_info[0].result["sql_server_exists"], "") == "true"
  db_instance_name = var.database_type != "NONE" ? try(data.external.sql_instance_info[0].result["instance_name"], "") : ""
  db_instance_region = var.database_type != "NONE" ? try(data.external.sql_instance_info[0].result["instance_region"], "") : ""
  database_version = var.database_type != "NONE" ? try(data.external.sql_instance_info[0].result["database_version"], "") : ""
  db_internal_ip = var.database_type != "NONE" ? try(data.external.sql_instance_info[0].result["instance_ip"], "") : ""
  db_root_password = var.database_type != "NONE" ? try(data.external.sql_instance_info[0].result["root_password"], "") : ""
}
