apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: '0'
        autoscaling.knative.dev/maxScale: '3'
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: ${REPO_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        ports:
        - name: http1
          containerPort: 80
        resources:
          limits:
            cpu: 1000m
            memory: 2000Mi
        livenessProbe:
          initialDelaySeconds: 180
          timeoutSeconds: 1
          periodSeconds: 10
          failureThreshold: 3
          httpGet:
            path: /
            port: 80
        startupProbe:
          timeoutSeconds: 120
          periodSeconds: 240
          failureThreshold: 1
          tcpSocket:
            port: 80
