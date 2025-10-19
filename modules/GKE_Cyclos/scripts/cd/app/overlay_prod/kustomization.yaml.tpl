apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${APP_NAMESPACE}
nameSuffix: prod
commonLabels:
  app: ${APP_NAME}prod
  ns: ${APP_NAMESPACE}
images:
- name: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newName: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newTag: "${IMAGE_VERSION}"
resources:
- ../base_prod
- statefulset-app.yaml
- managedcert-app.yaml
- ingress-app.yaml
