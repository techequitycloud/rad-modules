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
      annotations:
        gke-gcsfuse/volumes: "true"
      labels:
        app: ${APP_NAME}
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccountName: ${APP_NAME}${APP_ENV}
      containers:
      - name: ${APP_NAME}
        image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        imagePullPolicy: Always
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 120
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 180
          periodSeconds: 20
        ports:
        - containerPort: 80
          protocol: TCP
        volumeMounts:
          - name: shared-volume
            mountPath: "/mnt"
        env:
          - name: PORT
            value: "80"
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
          - name: NFS_IP_ADDRESS
            value: ${APP_NFS_IP}
          - name: APP_URL
            valueFrom:
              configMapKeyRef:
                name: ${APP_NAME}
                key: APP_URL
          - name: SSL_PROXY
            valueFrom:
              configMapKeyRef:
                name: ${APP_NAME}
                key: SSL_PROXY
          - name: PHP_INI_SCAN_DIR
            value: :/etc/config
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
          requests:
            cpu: 1000m
            memory: 2000Mi
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: ${NFS_PVC}
        - name: php-config
          configMap:
            name: ${APP_NAME}php
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}
data:
  APP_URL: ${APP_DOMAIN}
  SSL_PROXY: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}php
data:
  php.ini: |
    upload_max_filesize=128M
    post_max_size=256M
    max_execution_time=1800
    memory_limit = 256M
    max_input_vars = 5000