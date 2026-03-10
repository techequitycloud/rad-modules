apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    type: HTTP
    requestPath: /
  iap:
    enabled: false
    oauthclientCredentials:
      secretName: iap-secret
