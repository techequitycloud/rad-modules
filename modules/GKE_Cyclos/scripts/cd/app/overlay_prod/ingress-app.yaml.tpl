apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APP_IP}prod
    networking.gke.io/managed-certificates: ${APP_NAME}prod
spec:
  rules:
  - host: ${APP_DOMAIN}
    http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: ${APP_NAME}
            port:
              number: 80
  defaultBackend:
    service:
      name: ${APP_NAME}
      port:
        number: 80
