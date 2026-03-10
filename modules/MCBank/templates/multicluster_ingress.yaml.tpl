apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: ${APPLICATION_NAME}-mci
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
spec:
  template:
    spec:
      backend:
        serviceName:  ${APPLICATION_NAME}-mcs
        servicePort: 80