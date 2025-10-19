apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
spec:
  domains:
    - ${APPLICATION_DOMAIN}