apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_IP}
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}
    networking.gke.io/v1beta1.FrontendConfig: ${APPLICATION_NAME}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
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