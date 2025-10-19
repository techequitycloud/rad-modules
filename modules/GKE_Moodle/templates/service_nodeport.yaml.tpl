apiVersion: v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    cloud.google.com/backend-config: '{"ports": {"http": "${APPLICATION_NAME}"}}'
    cloud.google.com/neg: '{"ingress": true}'
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  type: ClusterIP
  selector: 
    app: ${APPLICATION_NAME}
  sessionAffinity: None
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80