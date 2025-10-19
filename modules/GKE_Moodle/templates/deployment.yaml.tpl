apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  selector:
    matchLabels:
      ns: ${APPLICATION_NAMESPACE}
      app: ${SERVICE_ACCOUNT_NAME}
  template:
    metadata:
      annotations:
        gke-gcsfuse/volumes: "true"
      labels:
        ns: ${APPLICATION_NAMESPACE}
        app: ${SERVICE_ACCOUNT_NAME}
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccountName: ${APPLICATION_NAME}
      containers:
      - name: ${APPLICATION_NAME}
        image: ${APPLICATION_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
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
          protocol: TCP
        volumeMounts:
          - name: shared-volume
            mountPath: "/mnt"
#          - name: gcs-volume
#            mountPath: /data
#            readOnly: false
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
                name: ${APPLICATION_NAME}-password
                key: password
          - name: NFS_IP_ADDRESS
            value: ${APPLICATION_NFS_IP}
          - name: APP_URL
            valueFrom:
              configMapKeyRef:
                name: ${APPLICATION_NAME}
                key: APP_URL
          - name: SSL_PROXY
            valueFrom:
              configMapKeyRef:
                name: ${APPLICATION_NAME}
                key: SSL_PROXY
          - name: PHP_INI_SCAN_DIR
            value: :/etc/config
        resources:
          limits:
            cpu: 1000m
            memory: 2000Mi
          requests:
            cpu: 500m
            memory: 1000Mi
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: ${NFS_PVC}
        - name: php-config
          configMap:
            name: ${APPLICATION_NAME}php
#        - name: gcs-volume
#          persistentVolumeClaim:
#            claimName: ${GCS_DATA_PVC}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
data:
  APP_URL: ${APPLICATION_DOMAIN}
  SSL_PROXY: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APPLICATION_NAME}php
  namespace: ${APPLICATION_NAMESPACE}
data:
  php.ini: |
    upload_max_filesize=128M
    post_max_size=256M
    max_execution_time=1800
    memory_limit = 256M
    max_input_vars = 5000