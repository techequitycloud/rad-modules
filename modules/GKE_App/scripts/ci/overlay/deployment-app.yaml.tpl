apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APP_NAME}
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SERVICE_ACCOUNT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APP_NAME}
spec:
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      terminationGracePeriodSeconds: 25
      serviceAccountName: ${APP_NAME}${APP_ENV}
      containers:
      - name: ${APP_NAME}
        image: nginx:latest
        imagePullPolicy: Always
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
        ports:
        - containerPort: 80
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
              name: ${DATABASE_SECRET}
              key: password
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
          requests:
            cpu: 1000m
            memory: 2000Mi
