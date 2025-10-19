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
  strategy:
    type: Recreate
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
      containers:
      - name: ${APPLICATION_NAME}
        image: "openemr/openemr:7.0.3"
        resources:
          limits:
            cpu: "2"
            ephemeral-storage: 2Gi
            memory: 2000Mi
          requests:
            cpu: "1"
            ephemeral-storage: 2Gi
            memory: 1000Mi
        imagePullPolicy: Always
        readinessProbe:
          httpGet:
            path: /
            port: 80
            scheme: HTTP
          initialDelaySeconds: 240
          timeoutSeconds: 10
          periodSeconds: 240
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /interface/login/login.php
            port: 80
            scheme: HTTP
          initialDelaySeconds: 600
          timeoutSeconds: 5
          periodSeconds: 60
          failureThreshold: 3
        ports:
        - containerPort: 80
          protocol: TCP
        - containerPort: 443
          protocol: TCP
        volumeMounts:
          - name: shared-volume
            mountPath: "/var/www/localhost/htdocs/openemr/sites"
        env:
          - name: PORT
            value: "80"
          - name: MYSQL_USER
            value: ${DATABASE_USER}
          - name: MYSQL_DATABASE
            value: ${DATABASE_NAME}
          - name: MYSQL_HOST
            value: ${DATABASE_HOST}
          - name: MYSQL_PORT
            value: "3306"
          - name: MYSQL_PASS
            valueFrom:
              secretKeyRef:
                name: ${APPLICATION_NAME}-password
                key: password
          - name: MYSQL_ROOT_PASS
            valueFrom:
              secretKeyRef:
                name: ${APPLICATION_NAME}-root-password
                key: password
          - name: OE_USER
            value: "admin"
          - name: OE_PASS
            value: "admin"
          - name: NFS_IP_ADDRESS
            value: ${APPLICATION_NFS_IP}
          - name: PHP_INI_SCAN_DIR
            value: :/etc/php83
      restartPolicy: Always     
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: ${NFS_PVC}
        - name: php-config
          configMap:
            name: ${APPLICATION_NAME}php
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APPLICATION_NAME}php
  namespace: ${APPLICATION_NAMESPACE}
data:
  php.ini: |
    upload_max_filesize=128M
    post_max_size=256M
    max_execution_time=180
    memory_limit = 512M
    max_input_vars = 5000