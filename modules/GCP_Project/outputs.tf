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

output "agent_project_id" {
  description = "Project ID of the agent project"
  value       = google_project.project.project_id
}

output "rad_agent_email" {
  description = "Email of the rad-agent service account. Use this service account for impersonation when deploying into a project you own."
  value       = google_service_account.rad_agent.email
}


