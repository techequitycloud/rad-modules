apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_SERVICE}
  labels:
    app: ${APP_NAME}
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    metadata:
      labels:
        app: ${APP_NAME}
      annotations:
        autoscaling.knative.dev/minScale: '0'
        autoscaling.knative.dev/maxScale: '3'
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: ${HOST_PROJECT_ID}:${APP_REGION}:${DATABASE_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/${HOST_PROJECT_ID}/locations/${APP_REGION}/connectors/connector
        run.googleapis.com/vpc-access-egress: all-traffic
    spec:
      serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
      containers:
      - image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        ports:
        - containerPort: 8069
        resources:
          limits:
            cpu: 1000m
            memory: 2Gi
        env:
        - name: USER
          value: odoo
        - name: POSTGRES_DB_HOST
          value: ${DATABASE_HOST}
        - name: POSTGRES_USER
          value: ${DATABASE_USER}
        - name: POSTGRES_DB
          value: ${DATABASE_NAME}
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ${DATABASE_PASSWORD}
              key: latest
        - name: ODOO_ADMIN_PASSWORD
          value: odoo
        volumeMounts:
        - name: nfs
          mountPath: /var/lib/odoo
        startupProbe:
          tcpSocket:
            port: 8069
          timeoutSeconds: 240
          periodSeconds: 240
          failureThreshold: 1
      volumes:
      - name: nfs
        nfs:
          server: ${APP_NFS_IP}
          path: /share/${APP_DATA_DIR}
          readOnly: false
