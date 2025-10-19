steps:
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.1.0'
    entrypoint: 'bash'
    args:
    - '-c'
    - |
            gcloud --project ${PROJECT_ID} container clusters get-credentials ${GKE_CLUSTER} --region=${APP_REGION} && sleep 5 && skaffold run -p ${APP_ENV} --kubeconfig ~/.kube/config 
    env:
    - 'ENV=latest-${APP_ENV}'
    id: Deploy to GKE cluster in ${APP_ENV} environment
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  logging: CLOUD_LOGGING_ONLY
