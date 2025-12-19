apiVersion: skaffold/v3alpha1
kind: Config
metadata:
  name: ${APP_NAME}
build:
  artifacts:
  - image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
    docker:
      dockerfile: Dockerfile
profiles:
- name: main
  manifests:
    rawYaml:
    - deploy.yaml
