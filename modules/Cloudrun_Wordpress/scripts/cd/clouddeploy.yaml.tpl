apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: ${PIPELINE_NAME}
 labels:
  app: ${APP_NAME}
description: ${APP_NAME} Cloud Run delivery pipeline
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
description: Cloud Run development service
run:
 location: projects/${PROJECT_ID}/locations/${APP_REGION}
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
description: Cloud Run staging service
run:
 location: projects/${PROJECT_ID}/locations/${APP_REGION}
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
description: Cloud Run production service
requireApproval: true
run:
 location: projects/${PROJECT_ID}/locations/${APP_REGION}
executionConfigs:
- usages:
  - RENDER
  - PREDEPLOY
  - DEPLOY
  - VERIFY 
  - POSTDEPLOY
  serviceAccount: ${CREATOR_SA}
