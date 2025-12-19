apiVersion: skaffold/v3alpha1
kind: Config
metadata: 
  name: ${APP_NAME}
manifests:
  rawYaml:
  - deploy.yaml
deploy:
  cloudrun: {}
