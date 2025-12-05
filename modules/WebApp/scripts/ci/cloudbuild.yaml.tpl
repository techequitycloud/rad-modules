steps:
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.12.0'
    args:
      [
      'skaffold','build', '--interactive=false', '--file-output=/workspace/artifacts.json'
      ]
    env:
    - 'ENV=latest-${APP_ENV}'
    id: Build and package app
#  - name: 'gcr.io/${PROJECT_ID}/binauthz-attestation:latest'
#    args:
#      - '--artifact-url'
#      - '${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:latest-${APP_ENV}'
#      - '--attestor'
#      - 'binauth-attestor'
#      - '--attestor-project'
#      - '${PROJECT_ID}'
#      - '--keyversion'
#      - '1'
#      - '--keyversion-project'
#      - '${PROJECT_ID}'
#      - '--keyversion-location'
#      - '${APP_REGION}'
#      - '--keyversion-keyring'
#      - 'binauth-keyring'
#      - '--keyversion-key'
#      - 'binauth-key'
#      - '--keyversion'
#      - '1'
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
