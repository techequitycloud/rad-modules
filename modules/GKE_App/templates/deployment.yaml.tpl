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
      labels:
        ns: ${APPLICATION_NAMESPACE}
        app: ${SERVICE_ACCOUNT_NAME}
    spec:
      terminationGracePeriodSeconds: 25
      serviceAccountName: ${APPLICATION_NAME}
      containers:
      - name: ${APPLICATION_NAME}
        image: nginx:latest
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
                name: ${APPLICATION_NAME}-password
                key: password
        resources:
          limits:
            cpu: 1000m
            memory: 2000Mi
          requests:
            cpu: 500m
            memory: 1000Mi