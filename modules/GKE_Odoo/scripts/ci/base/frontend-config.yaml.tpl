apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: ${APP_NAME}
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "301"
