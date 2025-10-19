apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APP_NAME}
  namespace: ${APP_NAMESPACE}
  labels:
    ns: ${APP_NAMESPACE}
    app: ${APP_NAME}
spec:
  selector:
    matchLabels:
      ns: ${APP_NAMESPACE}
      app: ${APP_NAME}
  template:
    metadata:
      annotations:
        gke-gcsfuse/volumes: "true"
      labels:
        ns: ${APP_NAMESPACE}
        app: ${APP_NAME}
    spec:
      terminationGracePeriodSeconds: 60
      serviceAccountName: ${APP_NAME}
      initContainers:
        - name: check-mysql-connection
          image: mysql:8.0
          resources:
            limits:
              cpu: 500m
              ephemeral-storage: 1Gi
              memory: 1000Mi
            requests:
              cpu: 250m
              ephemeral-storage: 1Gi
              memory: 500Mi
        command:
            - sh
            - -c
            - |
              timeout 60 sh -c 'until mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS -e "SELECT 1;" >/dev/null 2>&1; do echo "Waiting for MySQL to be ready..."; sleep 2; done'
          env:
            - name: MYSQL_USER
              value: ${DATABASE_USER}
            - name: MYSQL_HOST
              value: ${DATABASE_HOST}
            - name: MYSQL_PORT
              value: "3306"
            - name: MYSQL_PASS
              valueFrom:
                secretKeyRef:
                  name: ${APP_NAME}-password
                  key: password
      containers:
      - name: ${APP_NAME}
        image: openemr/openemr:7.0.3
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
        - containerPort: 443
          protocol: TCP
        - containerPort: 80
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
                name: ${APP_NAME}-password
                key: password
          - name: MYSQL_ROOT_PASS
            valueFrom:
              secretKeyRef:
                name: ${APP_NAME}-root-password
                key: password
          - name: OE_USER
            value: "admin"
          - name: OE_PASS
            value: "admin"
          - name: NFS_IP_ADDRESS
            value: ${APP_NFS_IP}
          - name: PHP_INI_SCAN_DIR
            value: :/etc/php83
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: ${NFS_PVC}
        - name: php-config
          configMap:
            name: ${APP_NAME}php
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}php
  namespace: ${APP_NAMESPACE}
data:
  php.ini: |
    upload_max_filesize=128M
    post_max_size=256M
    max_execution_time=180
    memory_limit = 512M
    max_input_vars = 5000