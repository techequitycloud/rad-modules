apiVersion: batch/v1
kind: CronJob
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  schedule: "0 0 * * *"  # This cron expression means "midnight every day"
  jobTemplate:
    spec:
      backoffLimit: 0  # Number of retries before considering the job as failed
      template:
        metadata:
          labels:
            app: ${APP_NAME}
          annotations:
            gke-gcsfuse/volumes: "true"
        spec:
          restartPolicy: Never  # Ensures the job is not restarted if it fails
          serviceAccountName: ${SERVICE_ACCOUNT_NAME}
          securityContext: 
            runAsUser: 101
            runAsGroup: 101
            fsGroup: 101
          containers:
          - name: backup
            image: ${APP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
            imagePullPolicy: Always
            volumeMounts:
              - name: shared-volume
                mountPath: "/mnt"
              - name: gcs-volume
                mountPath: /data
                readOnly: false
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
                    name: ${DATABASE_SECRET}
              - name: BACKUP_BUCKET
                value: ${BACKUP_BUCKET}
            resources:
              limits:
                cpu: 500m
                memory: 768Mi
              requests:
                cpu: 100m
                memory: 256Mi
          volumes:
            - name: shared-volume
              persistentVolumeClaim:
                claimName: ${NFS_PVC}
            - name: gcs-volume
              persistentVolumeClaim:
                claimName: ${GCS_DATA_PVC}
