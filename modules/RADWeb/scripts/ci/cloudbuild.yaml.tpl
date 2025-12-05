steps:
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.12.0'
    args:
      [
      'skaffold','build', '--interactive=false', '--file-output=/workspace/artifacts.json'
      ]
    env:
    - 'ENV=latest-${APP_ENV}'
    id: Build and package app
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.12.0'
    entrypoint: 'bash'
    args:
    - '-c'
    - |
            skaffold run -p primary --cloud-run-location=${PRIMARY_HA_REGION}
    id: Deploy primary ${IMAGE_NAME}${APP_ENV} service to ${APP_ENV} environment
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  logging: CLOUD_LOGGING_ONLY
