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

# Destroy behaviour notes
# ────────────────────────────────────────────────────────────────────────────
# All Compute Engine instances (Windows VM and Linux VMs) are managed by
# Terraform and are deleted on `terraform destroy`.
#
# The Cloud Storage bucket uses force_destroy = true so the SSH key object
# is removed along with the bucket on destroy.
#
# Migration Center resources (import jobs, groups, preference sets, report
# configs, reports) are created via null_resource local-exec and are NOT
# tracked in Terraform state. They must be deleted manually from the
# Migration Center console, or they will be cleaned up automatically when
# the GCP project is deleted.
#
# The google_project_iam_member.migrationcenter_sa_user resource carries
# prevent_destroy = true. To destroy it, run:
#   terraform state rm google_project_iam_member.migrationcenter_sa_user
# then re-run terraform destroy.
# ────────────────────────────────────────────────────────────────────────────
