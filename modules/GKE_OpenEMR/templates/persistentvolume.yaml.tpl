apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${NFS_PV}
spec:
  storageClassName: "${NFS_STORAGE_CLASS}"
  capacity:
    storage: 3Gi
  accessModes:
  - ReadWriteMany
  nfs:
    server: ${APPLICATION_NFS_IP}
    path: "/share/${DATABASE_NAME}"
  persistentVolumeReclaimPolicy: Delete
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${GCS_DATA_PV}
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 5Gi
  storageClassName: "${GCS_STORAGE_CLASS}"
  mountOptions:
    - implicit-dirs
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: ${ADDON_BUCKET_NAME}
    volumeAttributes:
      gcsfuseLoggingSeverity: warning