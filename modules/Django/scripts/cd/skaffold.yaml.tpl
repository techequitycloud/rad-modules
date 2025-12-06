apiVersion: skaffold/v3alpha1
kind: Config
metadata:
  name: ${APP_NAME}
profiles:
- name: dev
  manifests:
    rawYaml:
    - deploy-dev.yaml
- name: qa
  manifests:
    rawYaml:
    - deploy-qa.yaml
- name: prod
  manifests:
    rawYaml:
    - deploy-prod.yaml
deploy:
  cloudrun: {}
