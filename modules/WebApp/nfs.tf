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
# Get Server Instance Info
#########################################################################

data "external" "nfs_instance_info" {
  count   = var.enable_nfs ? 1 : 0
  program = ["bash", "${path.module}/scripts/app/get-nfsserver-info.sh", local.project.project_id, local.region, local.impersonation_service_account]
}

#########################################################################
# Local variables for NFS infrastructure existence checks
#########################################################################

locals {
  nfs_instance_name = var.enable_nfs ? try(data.external.nfs_instance_info[0].result["gce_instance_name"], "") : ""
  nfs_internal_ip = var.enable_nfs ? try(data.external.nfs_instance_info[0].result["gce_instance_internalIP"], "") : ""
  nfs_instance_zone = var.enable_nfs ? try(data.external.nfs_instance_info[0].result["gce_instance_zone"], "") : ""

  nfs_server_exists = (
    var.enable_nfs &&
    local.nfs_instance_name != "" &&
    local.nfs_internal_ip != "" &&
    local.nfs_instance_zone != ""
  )
}
