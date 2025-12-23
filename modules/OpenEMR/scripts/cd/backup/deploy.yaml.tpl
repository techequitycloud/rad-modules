apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: ${SERVICE_NAME}
  labels:
    cloud.googleapis.com/location: ${APP_REGION}
  annotations:
    run.googleapis.com/launch-stage: BETA
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
    run.googleapis.com/description: "OpenEMR backup job"
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/vpc-access-connector: projects/${PROJECT_ID}/locations/${APP_REGION}/connectors/vpc-connector-${APP_REGION}
        run.googleapis.com/vpc-access-egress: all-traffic
    spec:
      serviceAccountName: ${SERVICE_ACCOUNT}
      timeoutSeconds: 300
      containers:
      - image: ${IMAGE}
        env:
        - name: MYSQL_HOST
          value: ${DB_IP}
        - name: MYSQL_PORT
          value: "3306"
        - name: MYSQL_USER
          value: ${DB_USER}
        - name: MYSQL_PASS
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DB_PASS_SECRET}
        - name: MYSQL_DATABASE
          value: ${DB_NAME}
        - name: GCS_BUCKET
          value: ${GCS_BUCKET}
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /var/www/localhost/htdocs/openemr/sites
      volumes:
      - name: nfs-data-volume
        nfs:
          server: ${NFS_IP}
          path: /share/${DB_NAME}
          readOnly: false
