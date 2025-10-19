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
profiles:
- name: dev
  activation:
    - env: ENV=dev
    - kubeContext: gke_${PROJECT_ID}_${APP_REGION}_${GKE_CLUSTER}
  manifests:
    kustomize:
      paths: 
      - overlay_dev/
- name: qa
  activation:
    - env: ENV=qa
    - kubeContext: gke_${PROJECT_ID}_${APP_REGION}_${GKE_CLUSTER}
  manifests:
    kustomize:
      paths: 
      - overlay_qa/
- name: prod
  activation:
    - env: ENV=prod
    - kubeContext: gke_${PROJECT_ID}_${APP_REGION}_${GKE_CLUSTER}
  manifests:
    kustomize:
      paths: 
      - overlay_prod/
