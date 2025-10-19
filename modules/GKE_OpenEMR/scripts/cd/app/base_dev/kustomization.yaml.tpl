apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- service-cluster.yaml
- storage-pvc.yaml
- backend-config.yaml
- frontend-config.yaml
- autoscale-horizontal.yaml
