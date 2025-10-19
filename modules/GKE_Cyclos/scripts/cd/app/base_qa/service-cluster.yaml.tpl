apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  annotations:
    cloud.google.com/backend-config: '{"default": "${APP_NAME}qa"}'
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: NodePort
  selector:
    app: ${APP_NAME}qa
  sessionAffinity: None
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
