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
    - '--dockerfile=$${_DOCKERFILE}'
    - '--context=dir://$${_CONTEXT_PATH}'
    - '--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$${_IMAGE_VERSION}'
    - '--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:latest'
    - '--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$$COMMIT_SHA'
    - '--cache=true'
    - '--cache-ttl=24h'
%{ for key, value in BUILD_ARGS ~}
    - '--build-arg=${key}=${value}'
%{ endfor ~}
  timeout: '1800s'

# Deploy to Cloud Run
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk:slim'
  entrypoint: gcloud
  args:
    - 'run'
    - 'services'
    - 'update'
    - '$${_CLOUD_RUN_SERVICE}'
    - '--platform=managed'
    - '--region=$${_CLOUD_RUN_REGION}'
    - '--image=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$$COMMIT_SHA'
    - '--quiet'
  timeout: '600s'

serviceAccount: 'projects/$${_PROJECT_ID}/serviceAccounts/cloudbuild-sa@$${_PROJECT_ID}.iam.gserviceaccount.com'

options:
  logging: CLOUD_LOGGING_ONLY
  # machineType: 'E2_HIGHCPU_8'

timeout: '3600s'

# Substitutions (default values, can be overridden by trigger)
substitutions:
  _PROJECT_ID: '${PROJECT_ID}'
  _APP_NAME: '${APP_NAME}'
  _IMAGE_REGION: '${IMAGE_REGION}'
  _IMAGE_NAME: '${IMAGE_NAME}'
  _IMAGE_VERSION: '${IMAGE_VERSION}'
  _REPO_NAME: '${REPO_NAME}'
  _DOCKERFILE: '${DOCKERFILE}'
  _CONTEXT_PATH: '${CONTEXT_PATH}'
  _CLOUD_RUN_SERVICE: '${CLOUD_RUN_SERVICE}'
  _CLOUD_RUN_REGION: '${CLOUD_RUN_REGION}'
