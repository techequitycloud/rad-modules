apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${APP_NAMESPACE}
nameSuffix: qa
commonLabels:
  app: ${APP_NAME}qa
  ns: ${APP_NAMESPACE}
images:
- name: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newName: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newTag: "${IMAGE_VERSION}"
resources:
- ../base_qa
- deployment-app.yaml
- managedcert-app.yaml
- ingress-app.yaml
