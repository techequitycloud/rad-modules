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
# Cyclos Module Configuration
#########################################################################

# Load Cyclos module definition
module "cyclos_module" {
  source      = "./modules"
  app_version = var.application_version != "latest" ? var.application_version : "4.16.15"
}

#########################################################################
# Cyclos-Specific Locals
#########################################################################

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
