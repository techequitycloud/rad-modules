apiVersion: apps/v1
kind: StatefulSet
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
    app: ${SERVICE_ACCOUNT_NAME}
spec:
  serviceName: dns${APPLICATION_NAME}
  selector:
    matchLabels:
      ns: ${APPLICATION_NAMESPACE}
      app: ${SERVICE_ACCOUNT_NAME}
  template:
    metadata:
      labels:
        ns: ${APPLICATION_NAMESPACE}
        app: ${SERVICE_ACCOUNT_NAME}
    spec:
      terminationGracePeriodSeconds: 25
      serviceAccountName: ${APPLICATION_NAME}
      containers:
      - name: ${APPLICATION_NAME}
        image: ${APPLICATION_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_VERSION}
        imagePullPolicy: Always
        readinessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
        ports:
        - containerPort: 8080
        env:
          - name: DB_USER
            value: ${DATABASE_USER}
          - name: DB_NAME
            value: ${DATABASE_NAME}
          - name: DB_HOST
            value: ${DATABASE_HOST}
          - name: CLUSTER_K8S_DNS
            value: dns${APPLICATION_NAME}
          - name: DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: ${APPLICATION_NAME}-password
                key: password
        resources:
          limits:
            cpu: 2000m
            memory: 4000Mi
          requests:
            cpu: 1000m
            memory: 2000Mi