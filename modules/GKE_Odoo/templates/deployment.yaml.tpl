apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  selector:
    matchLabels:
      ns: ${APPLICATION_NAMESPACE}
      app: ${SERVICE_ACCOUNT_NAME}
  template:
    metadata:
      annotations:
        gke-gcsfuse/volumes: "true"
      labels:
        ns: ${APPLICATION_NAMESPACE}
        app: ${SERVICE_ACCOUNT_NAME}
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccountName: ${APPLICATION_NAME}
#      securityContext: 
#        runAsUser: 101
#        runAsGroup: 101
#        fsGroup: 101
      containers:
      - name: ${APPLICATION_NAME}
        image: ${APPLICATION_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        imagePullPolicy: Always
        ports:
        - containerPort: 8069
          protocol: TCP
        volumeMounts:
          - name: shared-volume
            mountPath: "/mnt"
#          - name: gcs-volume
#            mountPath: /data
#            readOnly: false
        env:
          - name: PORT
            value: "8069"
          - name: DB_USER
            value: ${DATABASE_USER}
          - name: DB_NAME
            value: ${DATABASE_NAME}
          - name: DB_HOST
            value: ${DATABASE_HOST}
          - name: DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: ${APPLICATION_NAME}-password
                key: password
          - name: NFS_IP_ADDRESS
            value: ${APPLICATION_NFS_IP}
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