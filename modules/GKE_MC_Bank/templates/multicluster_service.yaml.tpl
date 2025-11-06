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
  %{ for cluster in clusters ~}
  - link: "${cluster.region}/${cluster.gke_cluster_name}"
  %{ endfor ~}
