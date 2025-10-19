apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- service-cluster.yaml
- backend-config.yaml
- backend-config.yaml
- frontend-config.yaml
- autoscale-horizontal.yaml

