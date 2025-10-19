apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${NFS_PVC}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: "${NFS_STORAGE_CLASS}"
  volumeName: ${NFS_PV}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${GCS_DATA_PVC}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    ns: ${APPLICATION_NAMESPACE}
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: ${GCS_DATA_PV}
  storageClassName: "${GCS_STORAGE_CLASS}"