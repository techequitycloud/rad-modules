#!/usr/bin/env bash
# Step 0 of the DESTROY pipeline: prepare the workspace for a destroy.
#
# Extracted for the same reason as the create and update pipelines' apply
# scripts: Cloud Build rejects any single step arg over 10,000 characters,
# rejecting the BUILD before anything runs, so every destroy fails at once with
# a message naming no cause. This step was the largest left at 8,932, and
# check_step_arg_limits.py's own docstring records a destroy step crossing the
# limit once before and breaking every destroy in the platform.
#
# UNLIKE the create/update scripts, this one belongs to the step that does the
# wiping (line ~109 below deletes everything under /workspace before cloning the
# module repo). It therefore must NOT be run from /workspace: bash reads a
# script lazily as it executes, so deleting the file mid-run is undefined
# behaviour. The step's inline preamble copies it to the shared
# 'pipeline-scripts' volume and execs it from /pipeline, which survives.
#
# Cloud Build substitutions are NOT expanded here, so they arrive as environment
# variables set on the step:
#   MODULE_NAME, DEPLOYMENT_ID, DEPLOYMENT_BUCKET_ID, GIT_REPO_URL,
#   MODULE_GIT_REPO_URL
# GIT_TOKEN still arrives via the step's secretEnv, unchanged. For the same
# reason "$" is written plainly, never as Cloud Build's "$$" escape.
set -e

echo "🔥 INFRASTRUCTURE DESTROY INITIATED"
echo "========================================"
echo "Module: ${MODULE_NAME}"
echo "Deployment ID: ${DEPLOYMENT_ID}"
echo "Project: ${PROJECT_ID}"
echo "Bucket: ${DEPLOYMENT_BUCKET_ID}"
echo "Timestamp: $(date)"
echo "========================================"
echo "⚠️  WARNING: This will DESTROY all infrastructure!"
echo "========================================"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Safety guard: this build runs `tofu destroy` and a recursive
# `gsutil rm -r` of the deployment folder. ALLOW_LOOSE permits empty /
# sentinel substitutions, which would collapse the GCS path and risk
# deleting far more than one deployment. Refuse to run unless both the
# module name and deployment ID are set to real values.
if [ -z "${DEPLOYMENT_ID}" ] || [ "${DEPLOYMENT_ID}" = "none" ] || \
   [ -z "${MODULE_NAME}" ] || [ "${MODULE_NAME}" = "unknown" ]; then
    log "❌ Refusing to destroy: _MODULE_NAME and _DEPLOYMENT_ID must be set to real values"
    log "   _MODULE_NAME='${MODULE_NAME}'  _DEPLOYMENT_ID='${DEPLOYMENT_ID}'"
    exit 1
fi

log "🧹 Preparing environment..."

mkdir -p /tmp/deployment_files
cd /tmp/deployment_files

log "🔍 Checking for deployment files..."

FILES_PATH="gs://${DEPLOYMENT_BUCKET_ID}/deployments/${MODULE_NAME}/${DEPLOYMENT_ID}/files"

if ! gsutil ls "$FILES_PATH/${MODULE_NAME}.tar.gz" > /dev/null 2>&1; then
    # No archive: either nothing was ever applied (member failed early or
    # was CANCELLED), or the archive was lost while real infra exists.
    # Decided by what the STATE CONTAINS — backend.tf and an empty state are
    # both written during prepare, so file existence proves nothing.
    log "⚠️  No archive: $FILES_PATH/${MODULE_NAME}.tar.gz"
    log "🔍 Inspecting Terraform state for real resources..."

    RESOURCE_COUNT=""
    if gsutil cp "$FILES_PATH/backend.tf" /tmp/be.tf 2>/dev/null; then
        # Path derived from backend.tf, not assumed, so a prefix change is safe.
        SP=$(sed -n 's/.*prefix[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' /tmp/be.tf | head -1)
        SB=$(sed -n 's/.*bucket[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' /tmp/be.tf | head -1)
        if [ -n "$SP" ] && [ -n "$SB" ]; then
            if gsutil cp "gs://${SB}/${SP}default.tfstate" /tmp/probe.tfstate 2>/dev/null; then
                RESOURCE_COUNT=$(jq '(.resources // []) | length' /tmp/probe.tfstate 2>/dev/null)
                log "   Resources in state: ${RESOURCE_COUNT:-unreadable}"
            else
                log "   No state object — nothing applied."
                RESOURCE_COUNT=0
            fi
        fi
    else
        log "   No backend.tf — nothing applied."
        RESOURCE_COUNT=0
    fi

    if [ -z "$RESOURCE_COUNT" ]; then
        log "❌ Cannot read state to prove nothing exists — refusing."
        exit 1
    fi
    if [ "$RESOURCE_COUNT" -gt 0 ] 2>/dev/null; then
        log "❌ State records $RESOURCE_COUNT resource(s) but the archive is"
        log "   missing. Destroying without module source risks orphaning them."
        log "   Restore the archive, or remove resources manually then delete"
        log "   gs://${DEPLOYMENT_BUCKET_ID}/deployments/${MODULE_NAME}/${DEPLOYMENT_ID}/"
        exit 1
    fi

    log "✅ State holds no resources — nothing to destroy; cleaning up."
    touch /workspace/NOTHING_TO_DESTROY
fi

# Later tofu steps need the source/state this step unpacks — skip them.
if [ -f /workspace/NOTHING_TO_DESTROY ]; then
    log "⏭️  Skipping the remainder of environment preparation."
    exit 0
fi

log "📦 Downloading deployment metadata..."

gsutil cp "$FILES_PATH/repo_url.txt" . 2>/dev/null || true
gsutil cp "$FILES_PATH/commit_hash.txt" . 2>/dev/null || true

STORED_REPO_URL=""
COMMIT_HASH=""
if [ -f "repo_url.txt" ] && [ -s "repo_url.txt" ]; then
    STORED_REPO_URL=$(cat repo_url.txt)
    log "ℹ️  Stored repository URL: $STORED_REPO_URL"
fi
if [ -f "commit_hash.txt" ] && [ -s "commit_hash.txt" ]; then
    COMMIT_HASH=$(cat commit_hash.txt)
    log "ℹ️  Deployment commit hash (audit only): $COMMIT_HASH"
    log "ℹ️  Destroy always uses HEAD to pick up the latest cleanup logic"
fi

try_clone() {
    local repo="$1"
    if [ -z "$repo" ] || [ "$repo" = "none" ]; then return 1; fi
    log "📥 Trying to clone: $repo (HEAD)"
    find /workspace -mindepth 1 -delete 2>/dev/null || true
    if ! git clone "https://$GIT_TOKEN@github.com/$repo.git" /workspace 2>&1; then
        log "⚠️  Clone failed for $repo (token may lack read access)"
        return 1
    fi
    if [ ! -d "/workspace/modules/${MODULE_NAME}" ]; then
        log "⚠️  Cloned $repo but module ${MODULE_NAME} not found — skipping"
        return 1
    fi
    log "✅ Successfully cloned $repo at HEAD (module ${MODULE_NAME} found)"
    return 0
}

CLONE_SUCCESS=false

if [ -n "${MODULE_GIT_REPO_URL}" ] && [ "${MODULE_GIT_REPO_URL}" != "none" ] && [ "${MODULE_GIT_REPO_URL}" != "" ]; then
    if try_clone "${MODULE_GIT_REPO_URL}"; then
        CLONE_SUCCESS=true
    fi
fi

if [ "$CLONE_SUCCESS" != "true" ] && [ -n "$STORED_REPO_URL" ]; then
    if try_clone "$STORED_REPO_URL"; then
        CLONE_SUCCESS=true
    fi
fi

if [ "$CLONE_SUCCESS" != "true" ] && [ -n "${GIT_REPO_URL}" ] && [ "${GIT_REPO_URL}" != "none" ] && [ "${GIT_REPO_URL}" != "" ]; then
    if try_clone "${GIT_REPO_URL}"; then
        CLONE_SUCCESS=true
    fi
fi

if [ "$CLONE_SUCCESS" != "true" ]; then
    if try_clone "techequitycloud/rad-modules"; then
        CLONE_SUCCESS=true
    fi
fi

if [ "$CLONE_SUCCESS" != "true" ]; then
    log "⚠️  All clone attempts failed for module ${MODULE_NAME}"
    log "   Repos tried (in order):"
    log "     _MODULE_GIT_REPO_URL : ${MODULE_GIT_REPO_URL:-<not set>}"
    log "     Stored repo_url.txt  : ${STORED_REPO_URL:-<not found in GCS>}"
    log "     _GIT_REPO_URL        : ${GIT_REPO_URL:-<not set>}"
    log "     Default              : techequitycloud/rad-modules"
    log "🔄 Attempting GCS archive fallback for module ${MODULE_NAME}..."

    ARCHIVE_PATH="$FILES_PATH/${MODULE_NAME}.tar.gz"
    if gsutil ls "$ARCHIVE_PATH" > /dev/null 2>&1; then
        log "📦 Found deployment archive in GCS — restoring module source code..."
        find /workspace -mindepth 1 -delete 2>/dev/null || true
        mkdir -p "/workspace/modules/${MODULE_NAME}"
        gsutil cp "$ARCHIVE_PATH" /tmp/fallback.tar.gz
        tar -xzf /tmp/fallback.tar.gz -C "/workspace/modules/${MODULE_NAME}"
        rm -f /tmp/fallback.tar.gz
        if [ -d "/workspace/modules/${MODULE_NAME}" ] && \
           ls /workspace/modules/${MODULE_NAME}/*.tf > /dev/null 2>&1; then
            log "✅ Module source code restored from GCS archive (module was removed from git)"
            CLONE_SUCCESS=true
        else
            log "❌ GCS archive did not contain valid Terraform source for ${MODULE_NAME}"
        fi
    else
        log "❌ No deployment archive found in GCS at: $ARCHIVE_PATH"
    fi
fi

if [ "$CLONE_SUCCESS" != "true" ]; then
    log "❌ All recovery attempts failed for module ${MODULE_NAME}"
    log "   Could not obtain module source from git or GCS archive."
    log "   Ensure the 'git-access-token' secret has read access to a repo"
    log "   containing modules/${MODULE_NAME}/. For partner repos, pass"
    log "   _MODULE_GIT_REPO_URL=<org/repo> when triggering the destroy build."
    exit 1
fi

log "📦 Downloading and extracting state files..."
cd /tmp/deployment_files

gsutil cp "$FILES_PATH/${MODULE_NAME}.tar.gz" .

mkdir -p /tmp/deployment_files/extracted
tar -xzf "${MODULE_NAME}.tar.gz" -C /tmp/deployment_files/extracted

log "📂 Restoring state configuration to /workspace/modules/${MODULE_NAME}..."
cd /tmp/deployment_files/extracted

TARGET_DIR="/workspace/modules/${MODULE_NAME}"

if [ -f "backend.tf" ]; then
    cp backend.tf "$TARGET_DIR/"
    log "   Restored backend.tf"
else
    log "⚠️  backend.tf not found in archive - attempting download from GCS..."
    if gsutil cp "$FILES_PATH/backend.tf" "$TARGET_DIR/" 2>/dev/null; then
        log "✅ Downloaded backend.tf fallback"
    else
        log "⚠️  backend.tf not found in GCS either"
    fi
fi

if [ -f "terraform.tfvars.json" ]; then
    cp terraform.tfvars.json "$TARGET_DIR/"
    log "   Restored terraform.tfvars.json"
else
    log "⚠️  terraform.tfvars.json not found in archive - attempting download from GCS..."
    if gsutil cp "$FILES_PATH/terraform.tfvars.json" "$TARGET_DIR/" 2>/dev/null; then
        log "✅ Downloaded terraform.tfvars.json fallback"
    else
        log "⚠️  terraform.tfvars.json not found in GCS either"
    fi
fi

if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "$TARGET_DIR/"
    log "   Restored terraform.tfstate"
fi

log "📋 Workspace contents prepared:"
ls -la "$TARGET_DIR" || true

log "✅ Destroy environment prepared"
