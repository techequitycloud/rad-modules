apiVersion: v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    cloud.google.com/backend-config: '{"ports": {"http": "${APPLICATION_NAME}"}}'
    cloud.google.com/neg: '{"ingress": true}'
  labels:
    app: ${APPLICATION_NAME}
spec:
  type: ClusterIP
  selector:
    app: frontend
  sessionAffinity: None
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080