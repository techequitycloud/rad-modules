apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${APPLICATION_NAME}
  minReplicas: 1
  maxReplicas: 1
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
