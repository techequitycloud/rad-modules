apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: ${APP_SERVICE}
  labels:
    app: ${APP_NAME}
  annotations:
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    metadata:
      labels:
        app: ${APP_NAME}
      annotations:
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: ${HOST_PROJECT_ID}:${APP_REGION}:${DATABASE_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/${HOST_PROJECT_ID}/locations/${APP_REGION}/connectors/connector
        run.googleapis.com/vpc-access-egress: all-traffic
    spec:
      template:
        spec:
          serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
          containers:
          - image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
            resources:
              limits:
                cpu: 1000m
                memory: 512Mi
            env:
            - name: PGHOST
              value: ${DATABASE_HOST}
            - name: PGUSER
              value: ${DATABASE_USER}
            - name: PGDATABASE
              value: ${DATABASE_NAME}
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${DATABASE_PASSWORD}
                  key: latest
            - name: GCS_BUCKET
              value: ${BACKUP_BUCKET}
            - name: GCS_PATH
              value: backup
            - name: MODE
              value: backup
            - name: FILESTORE_IP_ADDRESS
              value: ${APP_NFS_IP}
            - name: FILESTORE_SHARE_NAME
              value: /share/${APP_DATA_DIR}
            - name: MOUNT_POINT
              value: /mnt/share
            volumeMounts:
            - name: nfs
              mountPath: /mnt/share
          volumes:
          - name: nfs
            nfs:
              server: ${APP_NFS_IP}
              path: /share/${APP_DATA_DIR}
              readOnly: false
