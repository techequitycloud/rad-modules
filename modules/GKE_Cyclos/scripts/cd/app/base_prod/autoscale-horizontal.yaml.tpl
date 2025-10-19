apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APP_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: ${APP_NAME}
  minReplicas: 1
  maxReplicas: 1
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80