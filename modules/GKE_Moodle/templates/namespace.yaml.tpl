apiVersion: v1
kind: Namespace
metadata:
  name: ${APPLICATION_NAMESPACE}
  annotations:
    name: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}