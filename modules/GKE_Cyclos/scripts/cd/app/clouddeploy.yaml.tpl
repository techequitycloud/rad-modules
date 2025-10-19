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
 
apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: ${PIPELINE_NAME}
 labels:
  app: ${APP_NAME}
description: ${APP_NAME} GKE delivery pipeline
serialPipeline:
 stages:
 - targetId: ${TARGET_NAME}-dev-env
   profiles: [dev]
 - targetId: ${TARGET_NAME}-qa-env
   profiles: [qa]
 - targetId: ${TARGET_NAME}-prod-env
   profiles: [prod]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}-dev-env
 labels:
  app: ${APP_NAME}
  env: dev
description: GKE development service
gke:
 cluster: projects/${PROJECT_ID}/locations/${APP_REGION}/clusters/${GKE_CLUSTER}
executionConfigs:
- usages:
  - RENDER
  - PREDEPLOY
  - DEPLOY
  - VERIFY 
  - POSTDEPLOY
  serviceAccount: ${CREATOR_SA}
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}-qa-env
 labels:
  app: ${APP_NAME}
  env: qa
description: GKE staging service
gke:
 cluster: projects/${PROJECT_ID}/locations/${APP_REGION}/clusters/${GKE_CLUSTER}
executionConfigs:
- usages:
  - RENDER
  - PREDEPLOY
  - DEPLOY
  - VERIFY 
  - POSTDEPLOY
  serviceAccount: ${CREATOR_SA}
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}-prod-env
 labels:
  app: ${APP_NAME}
  env: prod
description: GKE production service
requireApproval: true
gke:
 cluster: projects/${PROJECT_ID}/locations/${APP_REGION}/clusters/${GKE_CLUSTER}
executionConfigs:
- usages:
  - RENDER
  - PREDEPLOY
  - DEPLOY
  - VERIFY 
  - POSTDEPLOY
  serviceAccount: ${CREATOR_SA}
