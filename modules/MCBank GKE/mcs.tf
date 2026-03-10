/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "null_resource" "cleanup_mci_resources" {
  for_each = var.deploy_application ? local.cluster_configs : {}

  triggers = {
    cluster = each.value.gke_cluster_name
    region  = each.value.region
    project = local.project.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -x
      echo "======================================"
      echo "Starting MCI resource cleanup for cluster ${self.triggers.cluster}"
      echo "======================================"
      
      # Get cluster credentials
      if ! gcloud container clusters get-credentials ${self.triggers.cluster} \
          --region ${self.triggers.region} \
          --project ${self.triggers.project} 2>/dev/null; then
        echo "Warning: Could not get cluster credentials. Cluster may already be deleted."
        exit 0
      fi
      
      # Delete MultiClusterIngress and MultiClusterService
      kubectl delete mci --all -n bank-of-anthos 2>/dev/null || true
      kubectl delete mcs --all -n bank-of-anthos 2>/dev/null || true
      
      echo "======================================"
      echo "MCI resource cleanup completed"
      echo "======================================"
      
      exit 0
    EOF
  }
}
