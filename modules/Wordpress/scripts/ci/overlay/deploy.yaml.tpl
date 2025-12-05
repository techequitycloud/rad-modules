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
          containerPort: 80
        env:
        - name: WORDPRESS_DB_USER
          value: ${DATABASE_USER}
        - name: WORDPRESS_DB_NAME
          value: ${DATABASE_NAME}
        - name: WORDPRESS_DB_HOST
          value: ${DATABASE_HOST}
        - name: WORDPRESS_DEBUG
          value: "false"
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_PASSWORD}
        resources:
          limits:
            cpu: 1000m
            memory: 2000Mi
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /mnt
        - name: gcs-data-volume
          mountPath: /var/www/html/wp-content
        startupProbe:
          httpGet:
            path: /wp-admin/install.php
            port: 80
          initialDelaySeconds: 240
          periodSeconds: 240
          timeoutSeconds: 60
          failureThreshold: 5
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 300
          periodSeconds: 60
          timeoutSeconds: 60
          failureThreshold: 3
      volumes:
      - name: gcs-data-volume
        csi:
          driver: gcsfuse.run.googleapis.com
          volumeAttributes:
            bucketName: ${DATA_BUCKET}
      - name: nfs-data-volume
        nfs:
          server: ${APP_NFS_IP}
          path: ${SHARED_DIRECTORY}
  traffic:
  - percent: 100
    latestRevision: true