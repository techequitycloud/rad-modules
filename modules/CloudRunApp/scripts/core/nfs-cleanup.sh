#!/bin/bash
#
# NFS Cleanup Script for Google Cloud Run Jobs
# Implements graceful shutdown with signal escalation and proper error handling
# Compatible with Terraform destroy operations
#

set -euo pipefail

# Configuration
MOUNT_POINT="/mnt/nfs"
CLOUD_RUN_TIMEOUT=900        # Cloud Run job timeout (15 minutes default)
CLEANUP_TIMEOUT=850          # Internal timeout (50s buffer for logging)
SIGTERM_DURATION=800         # Initial SIGTERM attempt (50s for escalation)
FORCE_SUCCESS="${FORCE_SUCCESS:-false}"  # Set to 'true' for Terraform compatibility

# Logging functions
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

# Validate NFS_BASE_PATH
validate_path() {
    local path="$1"
    
    log_info "Validating NFS path: $path"
    
    # Check if path is empty
    if [ -z "$path" ]; then
        log_error "NFS_BASE_PATH is empty"
        return 1
    fi
    
    # Check for dangerous paths
    case "$path" in
        "/" | "." | ".." | "/*" | "/root" | "/home" | "/etc" | "/usr" | "/var")
            log_error "Dangerous NFS_BASE_PATH detected: '$path'. Aborting."
            return 1
            ;;
        */..* | */./* | *//*)
            log_error "Path contains suspicious patterns: '$path'. Aborting."
            return 1
            ;;
    esac
    
    # Ensure path starts with /share or expected prefix
    if [[ ! "$path" =~ ^/share/ ]]; then
        log_warning "Path does not start with /share/: '$path'"
    fi
    
    log_info "Path validation passed"
    return 0
}

# Check if directory exists and is within mount point
validate_target() {
    local target="$1"
    
    log_info "Validating target directory: $target"
    
    # Check if mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then
        log_error "Mount point $MOUNT_POINT does not exist"
        return 1
    fi
    
    # Check if mount point is actually mounted
    if ! mountpoint -q "$MOUNT_POINT"; then
        log_error "Mount point $MOUNT_POINT is not mounted"
        return 1
    fi
    
    # Verify target is within mount point (prevent directory traversal)
    local real_mount=$(realpath "$MOUNT_POINT")
    local real_target=$(realpath -m "$target")  # -m: don't require existence
    
    case "$real_target" in
        "$real_mount"/*)
            log_info "Target is within mount point: OK"
            ;;
        *)
            log_error "Target directory is not within mount point"
            log_error "  Mount point: $real_mount"
            log_error "  Target: $real_target"
            return 1
            ;;
    esac
    
    return 0
}

# Estimate directory size for timeout calculation
estimate_cleanup_time() {
    local target="$1"
    
    if [ ! -d "$target" ]; then
        echo "0"
        return
    fi
    
    log_info "Estimating cleanup time..."
    
    # Count files and directories (with timeout to prevent hanging)
    local file_count=$(timeout 30 find "$target" -type f 2>/dev/null | wc -l || echo "unknown")
    local dir_count=$(timeout 30 find "$target" -type d 2>/dev/null | wc -l || echo "unknown")
    
    log_info "Found approximately $file_count files and $dir_count directories"
    
    # Rough estimate: 1000 files per second for NFS
    if [ "$file_count" != "unknown" ] && [ "$file_count" -gt 0 ]; then
        local estimated_seconds=$((file_count / 1000 + 10))
        log_info "Estimated cleanup time: ${estimated_seconds}s"
        echo "$estimated_seconds"
    else
        echo "0"
    fi
}

# Perform cleanup with signal escalation
cleanup_directory() {
    local target="$1"
    local exit_code=0
    
    log_info "Starting cleanup of: $target"
    
    # Check if directory exists
    if [ ! -d "$target" ]; then
        log_info "Directory does not exist (already cleaned or never created)"
        return 0
    fi
    
    # Get directory size for logging
    local dir_size=$(du -sh "$target" 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Directory size: $dir_size"
    
    # Estimate cleanup time
    local estimated_time=$(estimate_cleanup_time "$target")
    if [ "$estimated_time" -gt "$SIGTERM_DURATION" ]; then
        log_warning "Estimated cleanup time (${estimated_time}s) exceeds SIGTERM timeout (${SIGTERM_DURATION}s)"
        log_warning "Consider increasing Cloud Run job timeout or cleaning in batches"
    fi
    
    # Attempt 1: Graceful cleanup with SIGTERM (allows proper cleanup)
    log_info "Attempt 1: Graceful cleanup with SIGTERM (timeout: ${SIGTERM_DURATION}s)"
    if timeout -s TERM "$SIGTERM_DURATION" rm -rf "$target" 2>&1 | tee /tmp/cleanup.log; then
        log_info "✓ Directory removed successfully with SIGTERM"
        return 0
    else
        exit_code=$?
        log_warning "SIGTERM cleanup failed or timed out (exit code: $exit_code)"
    fi
    
    # Check if directory still exists
    if [ ! -d "$target" ]; then
        log_info "✓ Directory was removed (despite timeout/error)"
        return 0
    fi
    
    # Attempt 2: Force cleanup with SIGKILL (last resort)
    local remaining_time=$((CLEANUP_TIMEOUT - SIGTERM_DURATION - 10))
    if [ "$remaining_time" -gt 30 ]; then
        log_warning "Attempt 2: Force cleanup with SIGKILL (timeout: ${remaining_time}s)"
        log_warning "This may leave stale NFS file handles"
        
        if timeout -s KILL "$remaining_time" rm -rf "$target" 2>&1 | tee -a /tmp/cleanup.log; then
            log_info "✓ Directory removed with SIGKILL"
            return 0
        else
            exit_code=$?
            log_error "SIGKILL cleanup failed (exit code: $exit_code)"
        fi
    else
        log_error "Insufficient time remaining for SIGKILL attempt"
    fi
    
    # Final check
    if [ ! -d "$target" ]; then
        log_info "✓ Directory was removed (despite errors)"
        return 0
    fi
    
    log_error "✗ Failed to remove directory after all attempts"
    
    # Show what's left
    log_info "Remaining contents (first 20 items):"
    ls -la "$target" 2>/dev/null | head -n 20 || log_error "Cannot list directory contents"
    
    return 1
}

# Main execution
main() {
    log_info "=== NFS Cleanup Script for Google Cloud Run Jobs ==="
    log_info "Cloud Run Timeout: ${CLOUD_RUN_TIMEOUT}s"
    log_info "Cleanup Timeout: ${CLEANUP_TIMEOUT}s"
    log_info "SIGTERM Duration: ${SIGTERM_DURATION}s"
    log_info "Force Success Mode: $FORCE_SUCCESS"
    
    # Validate input
    if ! validate_path "$NFS_BASE_PATH"; then
        log_error "Path validation failed"
        exit 1
    fi
    
    # Construct target directory
    TARGET_DIR="${MOUNT_POINT}${NFS_BASE_PATH}"
    log_info "Target Directory: $TARGET_DIR"
    
    # Validate target
    if ! validate_target "$TARGET_DIR"; then
        log_error "Target validation failed"
        exit 1
    fi
    
    # Perform cleanup
    if cleanup_directory "$TARGET_DIR"; then
        log_info "=== NFS Cleanup completed successfully ==="
        
        # Flush filesystem buffers
        log_info "Flushing filesystem buffers..."
        sync
        
        # Wait for NFS client to settle
        sleep 2
        
        log_info "Exiting with success status"
        exit 0
    else
        log_error "=== NFS Cleanup failed ==="
        
        # Flush buffers even on failure
        sync
        
        # Check if we should force success for Terraform compatibility
        if [ "$FORCE_SUCCESS" = "true" ]; then
            log_warning "FORCE_SUCCESS is enabled - exiting with success despite failure"
            log_warning "This prevents Terraform destroy from hanging, but cleanup was incomplete"
            exit 0
        else
            log_error "Exiting with failure status"
            log_error "Set FORCE_SUCCESS=true to prevent Terraform destroy from blocking"
            exit 1
        fi
    fi
}

# Trap signals for graceful shutdown
trap 'log_warning "Received SIGTERM, cleaning up..."; sync; exit 143' TERM
trap 'log_warning "Received SIGINT, cleaning up..."; sync; exit 130' INT

# Execute main function
main
