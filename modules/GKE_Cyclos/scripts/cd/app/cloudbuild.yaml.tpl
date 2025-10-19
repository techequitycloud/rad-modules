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

# [START cloudbuild_quickstart_build]
steps:
- name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
  entrypoint: gcloud
  args: 
    [
      'deploy', 'releases', 'create', 'release-$_RELEASE_TIMESTAMP','--delivery-pipeline', '${PIPELINE_NAME}','--region', '${IMAGE_REGION}','--images', 'app=${IMAGE_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}'
    ]
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  logging: CLOUD_LOGGING_ONLY
# [END cloudbuild_quickstart_build]
