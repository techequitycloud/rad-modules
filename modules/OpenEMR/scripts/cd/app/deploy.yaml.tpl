apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  labels:
    cloud.googleapis.com/location: ${APP_REGION}
  annotations:
    run.googleapis.com/launch-stage: BETA
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
    run.googleapis.com/description: "OpenEMR application service"
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
        autoscaling.knative.dev/minScale: '1'
        autoscaling.knative.dev/maxScale: '1'
        run.googleapis.com/vpc-access-connector: projects/${PROJECT_ID}/locations/${APP_REGION}/connectors/vpc-connector-${APP_REGION}
        run.googleapis.com/vpc-access-egress: all-traffic
    spec:
      serviceAccountName: ${SERVICE_ACCOUNT}
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: ${IMAGE}
        ports:
        - name: http1
          containerPort: 80
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
        - name: OE_USER
          value: admin
        - name: OE_PASS
          value: admin
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
        startupProbe:
          timeoutSeconds: 240
          periodSeconds: 240
          failureThreshold: 1
          tcpSocket:
            port: 80
        livenessProbe:
          httpGet:
            path: /interface/login/login.php
            port: 80
          initialDelaySeconds: 300
          timeoutSeconds: 1
          periodSeconds: 30
          failureThreshold: 3
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /var/www/localhost/htdocs/openemr/sites
      volumes:
      - name: nfs-data-volume
        nfs:
          server: ${NFS_IP}
          path: /share/${DB_NAME}
          readOnly: false
