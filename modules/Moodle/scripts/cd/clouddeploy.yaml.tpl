apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
  name: ${PIPELINE_NAME}
description: Cloud Deploy Pipeline
serialPipeline:
 stages:
 - targetId: ${TARGET_NAME}
   profiles: [${APP_NAME}]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: ${TARGET_NAME}
description: Cloud Run service
run:
 location: projects/${PROJECT_ID}/locations/${APP_REGION}
executionConfigs:
- usages:
  - RENDER
  - DEPLOY
  serviceAccount: ${CREATOR_SA}
