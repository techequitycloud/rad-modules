apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
  name: ${APP_NAME}
description: ${APP_NAME} pipeline
serialPipeline:
  stages:
  - targetId: ${APP_NAME}-dev
    profiles: []
  - targetId: ${APP_NAME}-qa
    profiles: []
  - targetId: ${APP_NAME}-prod
    profiles: []
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
  name: ${APP_NAME}-dev
description: ${APP_NAME} dev target
run:
  location: projects/${PROJECT_ID}/locations/${APP_REGION}
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
  name: ${APP_NAME}-qa
description: ${APP_NAME} qa target
run:
  location: projects/${PROJECT_ID}/locations/${APP_REGION}
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
  name: ${APP_NAME}-prod
description: ${APP_NAME} prod target
requireApproval: true
run:
  location: projects/${PROJECT_ID}/locations/${APP_REGION}
