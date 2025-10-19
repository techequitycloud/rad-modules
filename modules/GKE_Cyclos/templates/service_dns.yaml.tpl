apiVersion: v1
kind: Service
metadata:
  name: dns${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  clusterIP: None
  selector:
    app: ${APPLICATION_NAME}