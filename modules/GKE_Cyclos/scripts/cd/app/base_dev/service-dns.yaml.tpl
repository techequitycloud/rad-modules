apiVersion: v1
kind: Service
metadata:
  name: dns${APP_NAME}
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: ${APP_NAME}dev
