apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_SERVICE}
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/startup-cpu-boost: 'true'
#        run.googleapis.com/cpu-throttling: 'true'
        autoscaling.knative.dev/minScale: '0'
        autoscaling.knative.dev/maxScale: '3'
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
      containers:
      - image: app
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
            httpHeaders:
              - name: status
                value: pass
            port: 80
        startupProbe:
          initialDelaySeconds: 30
          timeoutSeconds: 240
          periodSeconds: 240
          failureThreshold: 3
          tcpSocket:
            port: 80
  traffic:
  - percent: 100
    latestRevision: true