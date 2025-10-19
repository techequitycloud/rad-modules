apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SERVICE_ACCOUNT}