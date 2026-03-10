apiVersion: v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    cloud.google.com/backend-config: '{"default": "${APPLICATION_NAME}"}'
    cloud.google.com/neg: '{"ingress": true}'
  labels:
    app: ${APPLICATION_NAME}
spec:
  type: NodePort
  selector:
    app: frontend
  sessionAffinity: None
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080 
---
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
---
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "301"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_NAME}
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}
spec:
  rules:
  - host: ${APPLICATION_DOMAIN}
    http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: ${APPLICATION_NAME}
            port:
              number: 80
  defaultBackend:
    service:
      name: ${APPLICATION_NAME}
      port:
        number: 80
---
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
---
apiVersion: v1
data:
   mesh: |-
      defaultConfig:
        tracing:
          stackdriver: {}
kind: ConfigMap
metadata:
   name: istio-asm-managed
   namespace: istio-system
