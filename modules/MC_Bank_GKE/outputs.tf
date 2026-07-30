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

# Output the deployment ID used within the module.
output "deployment_id" {
  description = "Module Deployment ID" # Description of what the deployment ID represents
  value       = var.deployment_id      # The value of the deployment ID passed as a variable
}

# Output the project ID for the configured project.
output "project_id" {
  description = "Project ID"             # Description of what the project ID represents
  value       = local.project.project_id # The value of the project ID from local variables
}