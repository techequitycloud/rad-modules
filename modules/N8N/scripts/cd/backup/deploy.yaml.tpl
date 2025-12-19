apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: ${APP_SERVICE}
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/vpc-access-egress: private-ranges-only
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/network-interfaces: '[{"network":"projects/${HOST_PROJECT_ID}/global/networks/${NETWORK_NAME}","subnetwork":"projects/${HOST_PROJECT_ID}/regions/${APP_REGION}/subnetworks/gce-vpc-subnet-${APP_REGION}","tags":["nfsserver"]}]'
    spec:
      parallelism: 1
      taskCount: 1
      template:
        spec:
          volumes:
          - name: gcs-backup-volume
            csi:
              driver: gcsfuse.run.googleapis.com
              volumeAttributes:
                bucketName: ${BACKUP_BUCKET}
          - name: nfs-data-volume
            nfs:
              server: ${APP_NFS_IP}
              path: /share/${DATABASE_NAME}
          containers:
          - image: app
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
                memory: 512Mi
                cpu: 1000m
            volumeMounts:
            - name: gcs-backup-volume
              mountPath: /data
            - name: nfs-data-volume
              mountPath: /mnt
          maxRetries: 3
          timeoutSeconds: '600'
          serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
