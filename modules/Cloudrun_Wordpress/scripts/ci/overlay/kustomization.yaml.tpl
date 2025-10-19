apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base/${HA_REGION}
images:
- name: ${REPO_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newName: ${REPO_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}
  newTag: latest-${APP_ENV}
nameSuffix: ${APP_ENV}
patchesStrategicMerge:
- deploy.yaml
