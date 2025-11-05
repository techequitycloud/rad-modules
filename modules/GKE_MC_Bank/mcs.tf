/**
 * Copyright 2025 Tech Equity Ltd
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

# ============================================
# Pre-cleanup for MultiCluster Ingress Resources
# ============================================
resource "null_resource" "cleanup_mci_resources" {
  for_each = var.deploy_application ? var.cluster_configs : {}

  triggers = {
    project = local.project.project_id
    cluster = each.value.gke_cluster_name
    region  = each.value.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -e
      echo "======================================"
      echo "Cleaning up MultiCluster Ingress Resources"
      echo "======================================"
      
      echo "Cleaning up from cluster ${self.triggers.cluster}..."
      if gcloud container clusters get-credentials ${self.triggers.cluster} \
          --region ${self.triggers.region} \
          --project ${self.triggers.project} 2>/dev/null; then
        
        echo "Deleting MultiClusterIngress resources from cluster ${self.triggers.cluster}..."
        kubectl delete multiclusteringress --all --all-namespaces --timeout=3m 2>/dev/null || true
        
        echo "Deleting MultiClusterService resources from cluster ${self.triggers.cluster}..."
        kubectl delete multiclusterservice --all --all-namespaces --timeout=3m 2>/dev/null || true
        
        # Remove finalizers if resources are stuck
        echo "Removing finalizers from cluster ${self.triggers.cluster}..."
        for mci in $(kubectl get multiclusteringress --all-namespaces -o name 2>/dev/null); do
          kubectl patch $mci -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
        
        for mcs in $(kubectl get multiclusterservice --all-namespaces -o name 2>/dev/null); do
          kubectl patch $mcs -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
        
        echo "Cluster ${self.triggers.cluster} cleanup completed"
      else
        echo "Could not connect to cluster ${self.triggers.cluster}, skipping cleanup"
      fi
      
      # Wait for cleanup to propagate
      echo "Waiting 30 seconds for resources to be fully cleaned up..."
      sleep 30
      
      echo "======================================"
      echo "MultiCluster Ingress Resources cleanup completed"
      echo "======================================"
      
      exit 0
    EOF
  }

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================
# MultiCluster Service Discovery Feature
# ============================================
resource "google_gke_hub_feature" "multicluster_servicediscovery" {
  count    = var.deploy_application ? 1 : 0
  name     = "multiclusterservicediscovery"
  location = "global"
  project  = local.project.project_id

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
    null_resource.cleanup_mci_resources,
  ]
}

# ============================================
# MultiCluster Ingress Feature
# ============================================
resource "google_gke_hub_feature" "multicluster_ingress" {
  count    = var.deploy_application ? 1 : 0
  name     = "multiclusteringress"
  location = "global"
  project  = local.project.project_id

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.gke_cluster["cluster1"].id
    }
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
    google_gke_hub_feature.multicluster_servicediscovery,
    null_resource.cleanup_mci_resources,
  ]
}
