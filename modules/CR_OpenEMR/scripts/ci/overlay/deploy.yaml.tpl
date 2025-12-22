apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: '1'
        autoscaling.knative.dev/maxScale: '1'
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: openemr/openemr:7.0.3
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: MYSQL_USER
          value: ${DATABASE_USER}
        - name: MYSQL_DATABASE
          value: ${DATABASE_NAME}
        - name: MYSQL_HOST
          value: ${DATABASE_HOST}
        - name: MYSQL_PORT
          value: 3306
        - name: OE_USER
          value: admin
        - name: OE_PASS
          value: admin
        - name: MANUAL_SETUP
          value: no
        - name: MYSQL_PASS
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_PASSWORD}
        - name: MYSQL_ROOT_PASS
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${DATABASE_ROOT_PASSWORD}
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
        volumeMounts:
        - name: nfs-data-volume
          mountPath: /var/www/localhost/htdocs/sites
        livenessProbe:
          initialDelaySeconds: 300
          timeoutSeconds: 60
          periodSeconds: 60
          failureThreshold: 3
          httpGet:
            path: /interface/login/login.php
            httpHeaders:
              - name: status
                value: pass
            port: 80
        startupProbe:
          initialDelaySeconds: 240
          timeoutSeconds: 60
          periodSeconds: 240
          failureThreshold: 5
          tcpSocket:
            port: 80
      volumes:
      - name: nfs-data-volume
        nfs:
          server: ${APP_NFS_IP}
          path: ${SHARED_DIRECTORY}
  traffic:
  - percent: 100
    latestRevision: true