/**
 * Copyright 2024 Google LLC
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

# Cleanup on destroy is handled by the managed resources themselves.
# All GCE instances, the GKE cluster, and VPC firewall rules are deleted
# by Terraform during tofu destroy.
#
# Note: Container images pushed to gcr.io or Artifact Registry during the lab
# are NOT managed by this module and must be deleted manually if no longer needed.
#
# Note: PersistentVolumeClaims and PersistentVolumes created by m2c migrate-data
# are Kubernetes resources in the GKE cluster and are deleted when the cluster
# is destroyed. If the cluster is retained, delete them manually:
#   kubectl delete pvc petclinic-db-pvc
