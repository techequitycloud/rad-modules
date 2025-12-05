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
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/startup-cpu-boost: 'true'
#        run.googleapis.com/cpu-throttling: 'true'
    spec:
      serviceAccountName: cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com
  traffic:
  - percent: 100
    latestRevision: true