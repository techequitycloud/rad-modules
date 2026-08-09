apiVersion: v1
data:
   mesh: |-
      defaultConfig:
        tracing:
          stackdriver: {}
kind: ConfigMap
metadata:
   name: istio-${ASM_REVISION}
   namespace: istio-system
