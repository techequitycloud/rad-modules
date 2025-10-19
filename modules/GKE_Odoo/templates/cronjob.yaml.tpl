apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  schedule: "0 0 * * *"  # This cron expression means "midnight every day"
  jobTemplate:
    spec:
      backoffLimit: 0  # Number of retries before considering the job as failed
      template:
        metadata:
          labels:
            ns: ${APPLICATION_NAMESPACE}
            app: ${SERVICE_ACCOUNT_NAME}
          annotations:
            gke-gcsfuse/volumes: "true"
        spec:
          restartPolicy: Never  # Ensures the job is not restarted if it fails
          serviceAccountName: ${SERVICE_ACCOUNT_NAME}
          containers:
          - name: backup
            image: ${APPLICATION_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
            imagePullPolicy: Always
            volumeMounts:
              - name: gcs-fuse-csi-static
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
            securityContext:
              privileged: true
          volumes:
            - name: gcs-fuse-csi-static
              persistentVolumeClaim:
                claimName: gcs-fuse-csi-static-db-pvc-${APPLICATION_NAME}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gcs-fuse-csi-db-pv-${APPLICATION_NAME}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 1Gi
  storageClassName: "gcs-volume"
  mountOptions:
    - implicit-dirs
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: ${BACKUP_BUCKET}
    volumeAttributes:
      gcsfuseLoggingSeverity: warning
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gcs-fuse-csi-static-db-pvc-${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: gcs-fuse-csi-db-pv-${APPLICATION_NAME}
  storageClassName: "gcs-volume"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcs-volume
provisioner: gcsfuse.csi.storage.gke.io
parameters:
  bucketName: ${BACKUP_BUCKET}
  gcsfuseLoggingSeverity: warning
  replicationType: none  # Options: none, multi-region, dual-region, standard
reclaimPolicy: Retain
volumeBindingMode: Immediate
