apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: '1'
        autoscaling.knative.dev/maxScale: '1'
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: ${REPO_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        ports:
        - name: http1
          containerPort: 8080
        env:
        - name: DB_USER
          value: ${DATABASE_USER}
        - name: DB_NAME
          value: ${DATABASE_NAME}
        - name: DB_HOST
          value: ${DATABASE_HOST}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_PASSWORD}
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
            path: /api
            port: 8080
        startupProbe:
          timeoutSeconds: 120
          periodSeconds: 240
          failureThreshold: 1
          tcpSocket:
            port: 8080
