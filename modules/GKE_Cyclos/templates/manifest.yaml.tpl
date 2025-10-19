apiVersion: v1
kind: Namespace
metadata:
  name: ${APPLICATION_NAMESPACE}
  annotations:
    name: ${APPLICATION_NAMESPACE}
  labels:
    app: ${APPLICATION_NAME}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SERVICE_ACCOUNT}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  serviceName: dns${APPLICATION_NAME}
  selector:
    matchLabels:
      app: ${APPLICATION_NAME}
  template:
    metadata:
      labels:
        app: ${APPLICATION_NAME}
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
            cpu: 500m
            memory: 1000Mi
---
apiVersion: v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    cloud.google.com/backend-config: '{"default": "${APPLICATION_NAME}"}'
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: NodePort
  selector:
    app: ${APPLICATION_NAME}
  sessionAffinity: None
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080 
---
apiVersion: v1
kind: Service
metadata:
  name: dns${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  clusterIP: None
  selector:
    app: ${APPLICATION_NAME}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: ${APPLICATION_NAME}
  minReplicas: 1
  maxReplicas: 1
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    type: HTTP
    requestPath: /global
  iap:
    enabled: false
    oauthclientCredentials:
      secretName: iap-secret
---
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "301"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_IP}
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}
spec:
  rules:
  - host: ${APPLICATION_DOMAIN}
    http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: ${APPLICATION_NAME}
            port:
              number: 80
  defaultBackend:
    service:
      name: ${APPLICATION_NAME}
      port:
        number: 80
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
spec:
  domains:
    - ${APPLICATION_DOMAIN}