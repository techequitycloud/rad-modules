# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

steps:
# Build with Kaniko (more reliable than Docker in Cloud Build)
- name: 'gcr.io/kaniko-project/executor:latest'
  args:
    - '--dockerfile=${DOCKERFILE}'
    - '--context=dir://.'
    - '--destination=${IMAGE_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}'
    - '--destination=${IMAGE_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:latest'
    - '--cache=true'
    - '--cache-ttl=24h'
    %{ for arg, val in BUILD_ARGS ~}
    - '--build-arg=${arg}=${val}'
    %{ endfor ~}
  timeout: '1800s'

serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'

options:
  logging: CLOUD_LOGGING_ONLY
  # machineType: 'E2_HIGHCPU_8'
  
timeout: '3600s'
