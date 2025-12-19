apiVersion: skaffold/v3alpha1
kind: Config
metadata:
  name: ${APP_NAME}
profiles:
- name: default
  manifests:
    rawYaml:
    - deploy.yaml
deploy:
  cloudrun: {}
