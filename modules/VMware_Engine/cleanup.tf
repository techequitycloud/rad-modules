#*
# * Copyright 2024 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
#

# Cleanup on destroy is handled by the managed resources themselves:
#   - google_vmwareengine_private_cloud  (timeouts.delete = 180m)
#   - google_vmwareengine_network_policy (deleted before the VEN via depends_on)
#
# The null_resource destroy provisioners that previously lived here were removed
# because they created race conditions: Terraform and the gcloud script both
# attempted deletion concurrently, causing the destroy run to error on
# "resource not found". Importing pre-existing resources into state via
# `tofu import` is the correct approach when untracked resources need lifecycle
# management.
