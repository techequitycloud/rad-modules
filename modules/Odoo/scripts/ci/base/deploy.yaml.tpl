apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APP_NAME}
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/invoker-iam-disabled: true
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: private-ranges-only
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/network-interfaces: '[{"network":"projects/${HOST_PROJECT_ID}/global/networks/${NETWORK_NAME}","subnetwork":"projects/${HOST_PROJECT_ID}/regions/${HA_REGION}/subnetworks/gce-vpc-subnet-${HA_REGION}","tags":["nfsserver"]}]'
        run.googleapis.com/cloudsql-instances: ${PROJECT_ID}:${APP_REGION}:${DATABASE_INSTANCE}
        run.googleapis.com/startup-cpu-boost: 'true'
#        run.googleapis.com/cpu-throttling: 'true'
    spec:
      serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
  traffic:
  - percent: 100
    latestRevision: true