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
        autoscaling.knative.dev/minScale: '1'
        autoscaling.knative.dev/maxScale: '1'
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
        - name: MYSQL_USER
          value: ${DATABASE_USER}
        - name: MYSQL_DATABASE
          value: ${DATABASE_NAME}
        - name: MYSQL_HOST
          value: ${DATABASE_HOST}
        - name: MYSQL_PORT
          value: 3306
        - name: OE_USER
          value: admin
        - name: OE_PASS
          value: admin
        - name: MANUAL_SETUP
          value: no
        - name: MYSQL_PASS
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_PASSWORD}
        - name: MYSQL_ROOT_PASS
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_ROOT_PASSWORD}
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /var/www/localhost/htdocs/openemr/sites
        - name: gcs-data-volume
          mountPath: /data
        livenessProbe:
          initialDelaySeconds: 300
          timeoutSeconds: 60
          periodSeconds: 60
          failureThreshold: 3
          httpGet:
            path: /interface/login/login.php
            httpHeaders:
              - name: status
                value: pass
            port: 80
        startupProbe:
          initialDelaySeconds: 240
          timeoutSeconds: 60
          periodSeconds: 240
          failureThreshold: 5
          tcpSocket:
            port: 80
      volumes:
      - name: gcs-data-volume
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