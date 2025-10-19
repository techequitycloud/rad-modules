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
apiVersion: skaffold/v3alpha1
kind: Config
metadata: 
  name: ${APP_NAME}
build:
  tagPolicy:
    envTemplate:
      template: "{{.ENV}}"
  artifacts:
  - image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
    kaniko: {}
  googleCloudBuild:
    projectId: ${PROJECT_ID}
profiles:
- name: ${APP_ENV}
  activation:
    - env: ENV=${APP_ENV}
    - kubeContext: gke_${PROJECT_ID}_${APP_REGION}_${GKE_CLUSTER}
  manifests:
    kustomize:
      paths: 
      - overlay/
