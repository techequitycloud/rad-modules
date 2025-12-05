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
        run.googleapis.com/vpc-access-egress: private-ranges-only
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/network-interfaces: '[{"network":"projects/${HOST_PROJECT_ID}/global/networks/${NETWORK_NAME}","subnetwork":"projects/${HOST_PROJECT_ID}/regions/${APP_REGION}/subnetworks/gce-vpc-subnet-${APP_REGION}","tags":["nfsserver"]}]'
        run.googleapis.com/cloudsql-instances: ${PROJECT_ID}:${APP_REGION}:${DATABASE_INSTANCE}
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
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /mnt
        - name: gcs-addon-volume
          mountPath: /data
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
      volumes:
      - name: gcs-addon-volume
        csi:
          driver: gcsfuse.run.googleapis.com
          volumeAttributes:
            bucketName: ${DATA_BUCKET}
      - name: nfs-data-volume
        nfs:
          server: ${APP_NFS_IP}
          path: /share/${DATABASE_NAME}
  traffic:
  - percent: 100
    latestRevision: true