apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  domains:
    - ${APPLICATION_DOMAIN}