apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: ${APPLICATION_NAME}-mcs
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
  - link: "${APPLICATION_REGION_1}/${APPLICATION_CLUSTER_1}"
  - link: "${APPLICATION_REGION_2}/${APPLICATION_CLUSTER_2}"