#!/bin/bash
# Copyright (c) Tech Equity Ltd
# set -x

PROJECT_ID=$PROJECT_ID
PROJECT_NUMBER=$PROJECT_NUMBER
APP_NAME=$APP_NAME
APP_REGION=$APP_REGION
SERVICE_ACCOUNT=$CREATOR_SA

gcloud run services add-iam-policy-binding ${APP_NAME} --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com" --role="roles/run.invoker" --region ${APP_REGION} $SA_ARG || true

gcloud compute backend-services update ${APP_NAME}-backend --global --iap=disabled,oauth2-client-id=${CLIENT_ID},oauth2-client-secret=${CLIENT_SECRET} $SA_ARG || true

