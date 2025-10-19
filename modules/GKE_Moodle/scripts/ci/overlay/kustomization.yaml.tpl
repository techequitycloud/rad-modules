apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${APP_NAMESPACE}${APP_ENV}
nameSuffix: ${APP_ENV}
commonLabels:
  app: ${APP_NAME}${APP_ENV}
  ns: ${APP_NAMESPACE}${APP_ENV}
images:
- name: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newName: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newTag: "${IMAGE_VERSION}"
resources:
- ../base
- deployment-app.yaml
- managedcert-app.yaml
- ingress-app.yaml
