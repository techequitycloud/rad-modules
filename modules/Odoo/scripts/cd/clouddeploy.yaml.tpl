apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: ${PIPELINE_NAME}
 labels:
  app: ${APP_NAME}
description: ${APP_NAME} Cloud Run delivery pipeline
serialPipeline:
 stages:
 - targetId: ${TARGET_NAME}
   profiles: [run]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}
 labels:
  app: ${APP_NAME}
description: Cloud Run service
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
