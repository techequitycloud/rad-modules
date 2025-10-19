apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APP_NAME}
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SERVICE_ACCOUNT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APP_NAME}
spec:
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      annotations:
        gke-gcsfuse/volumes: "true"
      labels:
        app: ${APP_NAME}
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccountName: ${APP_NAME}${APP_ENV}
      containers:
      - name: ${APP_NAME}
        image: ${APP_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        imagePullPolicy: Always
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
        ports:
        - containerPort: 80
          protocol: TCP
        volumeMounts:
          - name: shared-volume
            mountPath: "/var/www/html/wp-content"
#          - name: gcs-volume
#            mountPath: "/var/www/html/wp-content"
#            readOnly: false
        env:
          - name: PORT
            value: "80"
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
                name: ${APP_NAME}-password
                key: password
          - name: NFS_IP_ADDRESS
            value: ${APP_NFS_IP}
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
          requests:
            cpu: 1000m
            memory: 2000Mi
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: ${NFS_PVC}
#        - name: gcs-volume
#          persistentVolumeClaim:
#            claimName: ${GCS_DATA_PVC}
