apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
  name: ${PIPELINE_NAME}
description: Cloud Run service
serialPipeline:
 stages:
 - targetId: ${TARGET_NAME}-env
   profiles: [main]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}-env
description: Cloud Run service
run:
  location: projects/${PROJECT_ID}/locations/${APP_REGION}
executionConfigs:
- usages:
  - RENDER
  - DEPLOY
  serviceAccount: ${CREATOR_SA}
