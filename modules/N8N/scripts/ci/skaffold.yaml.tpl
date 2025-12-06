apiVersion: skaffold/v4beta11
kind: Config
metadata:
  name: ${APP_NAME}
build:
  tagPolicy:
    envTemplate:
      template: "{{.ENV}}"
  artifacts:
  - image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  googleCloudBuild:
    projectId: ${PROJECT_ID}
    serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'
profiles:
- name: primary
  activation:
    - env: ENV=${APP_ENV}
  manifests:
    kustomize:
      paths:
      - overlay/primary
- name: secondary
  activation:
    - env: ENV=${APP_ENV}
  manifests:
    kustomize:
      paths:
      - overlay/secondary
deploy:
  cloudrun:
    projectid: ${PROJECT_ID}
    region: ${APP_REGION}