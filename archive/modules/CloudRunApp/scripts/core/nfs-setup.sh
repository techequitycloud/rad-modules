          set -e
          echo "=== NFS Setup Job ==="
          echo "Tenant/Deployment: ${DIR_NAME}"
          echo "NFS Path: ${NFS_BASE_PATH}"

          MOUNT_POINT="/mnt/nfs"
          TARGET_DIR="${MOUNT_POINT}/${DIR_NAME}"

          echo "Target Directory: ${TARGET_DIR}"

          if [ ! -d "${MOUNT_POINT}" ]; then
            echo "Error: Mount point ${MOUNT_POINT} does not exist."
            exit 1
          fi

          # Create subdirectories for this deployment
          echo "Creating deployment-specific subdirectories..."
          mkdir -p "${TARGET_DIR}"

          echo "Setting permissions (NFS-safe)..."
          chmod 777 "${TARGET_DIR}" 2>/dev/null || echo "Warning: chmod on target failed"

          echo "NFS setup complete for deployment: ${DIR_NAME}"

          # Ensure clean exit
          sync
          echo "Job finished successfully"
          echo "Exiting with success status"
          sleep 1
          exit 0
