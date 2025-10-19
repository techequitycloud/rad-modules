apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "301"