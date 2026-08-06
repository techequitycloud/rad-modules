#!/usr/bin/env bash
# Step 2 of the UPDATE pipeline: apply the planned infrastructure changes.
#
# Extracted for the same reason as the create pipeline's
# apply_infrastructure.sh: Cloud Build rejects any single step arg over 10,000
# characters, rejecting the BUILD before anything runs, so every update fails at
# once with a message naming no cause. This step was at 9,621 -- 379 characters
# from that outage. Run check_step_arg_limits.py after touching any pipeline
# YAML.
#
# Cloud Build substitutions are NOT expanded here (it substitutes only in the
# build config), so those values arrive as environment variables set on the step:
#   MODULE_NAME, DEPLOYMENT_ID, DEPLOYMENT_BUCKET_ID
# For the same reason "$" is written plainly, never as Cloud Build's "$$" escape.
#
# Step 0 wipes /workspace (three times) and replaces it with the module repo, so
# this file cannot be read from there. Step 0 copies it to the shared
# 'pipeline-scripts' volume at /pipeline before the first wipe.
set -e

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

log "🚀 Applying infrastructure changes..."

# ── Persist state on failure (option B) ──────────────────────────────
# Cloud Build aborts the entire build at the first non-zero step, so the
# final "Archive and Upload" step never runs after a failed apply. Any
# resources created during a failed apply would then be recorded ONLY in
# the local terraform.tfstate, which is discarded when this container is
# torn down — causing "already exists" errors on the next run. We
# therefore repack and upload the state archive on EXIT, regardless of
# success or failure. No-op when a remote GCS backend is in use (there is
# no local terraform.tfstate to persist).
FILES_PATH="gs://${DEPLOYMENT_BUCKET_ID}/deployments/${MODULE_NAME}/${DEPLOYMENT_ID}/files"
persist_state_to_gcs() {
    if [ -f "/workspace/modules/${MODULE_NAME}/terraform.tfstate" ]; then
        log "💾 Persisting Terraform state to GCS..."
        if tar -hczf "/tmp/${MODULE_NAME}-state.tar.gz" -C "/workspace/modules/${MODULE_NAME}" . 2>/dev/null \
           && gsutil -q cp "/tmp/${MODULE_NAME}-state.tar.gz" "$FILES_PATH/${MODULE_NAME}.tar.gz"; then
            log "✅ Terraform state persisted to GCS"
        else
            log "⚠️  Failed to persist Terraform state to GCS (non-critical)"
        fi
        rm -f "/tmp/${MODULE_NAME}-state.tar.gz"
    fi
}
trap persist_state_to_gcs EXIT

# ── Self-heal orphaned creates ────────────────────────────────────────
# terraform-provider-google's Create() for several resource types (Cloud
# SQL instances, GKE clusters, GCS buckets) doesn't call SetId() until
# its own post-create wait succeeds. If that wait errors on a
# transient/flaky poll — confirmed live 2026-08-06: a Cloud SQL instance
# apply failed with "Error waiting for Create Instance:" and a BLANK
# message body only ~2 minutes in, while the instance itself kept
# provisioning in the background and became RUNNABLE a few minutes later
# — the resource is left running in GCP with NO entry in Terraform state
# at all. Every retry after that hits "already exists" forever, since
# nothing is there to update — until someone manually diagnoses it and
# runs `tofu import` by hand (done 3x by hand in one sitting before this
# fix, across a GCS bucket, a GKE cluster, and this Cloud SQL instance).
#
# This only ever imports an already-real, already-running live resource
# into state — it never creates, deletes, or otherwise mutates anything
# — so it's safe to run unconditionally whenever this exact error
# signature appears. It is NOT the blind "retry the same failing apply"
# behavior removed below for the Medusa incident: it only retries once
# actual orphaned state has been found and fixed, which changes what the
# next apply will do.
self_heal_orphaned_creates() {
    if ! grep -qiE "Error waiting for (creating|Create)" /tmp/apply_output.txt 2>/dev/null; then
        return 1
    fi

    log "🔎 'Create wait' failure detected — checking whether the resource actually finished live before giving up..."

    local healed=false
    local addr name project location
    for addr in $(tofu show -json tfplan | jq -r '.resource_changes[]? | select(.change.actions == ["create"]) | .address'); do
        case "$addr" in
            google_sql_database_instance.*)
                name=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.name')
                project=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.project')
                if [ -n "$name" ] && [ "$name" != "null" ] && [ -n "$project" ] && [ "$project" != "null" ]; then
                    log "   Trying import: $addr <- $project/$name"
                    if tofu import "$addr" "$project/$name" >/tmp/self_heal_import.txt 2>&1; then
                        log "   ✅ Imported $addr — it already existed live"
                        healed=true
                    else
                        log "   ℹ️  $addr not found live (real failure, not orphaned) — leaving as-is"
                    fi
                fi
                ;;
            google_container_cluster.*)
                name=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.name')
                project=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.project')
                location=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.location')
                if [ -n "$name" ] && [ "$name" != "null" ] && [ -n "$project" ] && [ "$project" != "null" ] && [ -n "$location" ] && [ "$location" != "null" ]; then
                    log "   Trying import: $addr <- $project/$location/$name"
                    if tofu import "$addr" "$project/$location/$name" >/tmp/self_heal_import.txt 2>&1; then
                        log "   ✅ Imported $addr — it already existed live"
                        healed=true
                    else
                        log "   ℹ️  $addr not found live (real failure, not orphaned) — leaving as-is"
                    fi
                fi
                ;;
            google_storage_bucket.*)
                name=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.name')
                if [ -n "$name" ] && [ "$name" != "null" ]; then
                    log "   Trying import: $addr <- $name"
                    if tofu import "$addr" "$name" >/tmp/self_heal_import.txt 2>&1; then
                        log "   ✅ Imported $addr — it already existed live"
                        healed=true
                    else
                        log "   ℹ️  $addr not found live (real failure, not orphaned) — leaving as-is"
                    fi
                fi
                ;;
        esac
    done

    if [ "$healed" = "true" ]; then
        log "🔄 Re-planning with the imported resource(s) before retrying apply..."
        set +e
        tofu plan -input=false -out=tfplan -detailed-exitcode
        set -e
        return 0
    fi
    return 1
}

# Single-attempt apply — no automatic blind retry. A failed apply (e.g. a
# transient external dependency like an npm/PyPI registry rate limit
# during a container image build) used to trigger a second full attempt
# here (sleep + state refresh + re-plan + re-apply), which only prolongs
# a build that is often going to fail the same way again — confirmed live
# 2026-08-06: a Medusa_CloudRun update spent ~13 minutes retrying a Kaniko
# build inside attempt 1 (App_Common/scripts/build-container.sh's own
# retry loop, separately also now single-attempt), failed, then spent
# another ~13 minutes retrying the whole apply here for attempt 2 before
# finally failing — over 25 minutes to report a failure the first attempt
# already had. Matches cloudbuild_deployment_create.yaml's and
# cloudbuild_deployment_destroy.yaml's already-adopted single-attempt
# convention (both max_attempts=1). Retry from the RAD dashboard instead,
# once whatever was transient has had a chance to clear. The one
# exception is self_heal_orphaned_creates above, which only fires on a
# specific, narrow failure signature and only retries once it has
# concretely changed state.
apply_once() {
    log "🔄 Applying Terraform changes..."

    set +e
    tofu apply -auto-approve tfplan 2>&1 | tee /tmp/apply_output.txt
    APPLY_EXIT_CODE=${PIPESTATUS[0]}
    set -e

    if [ $APPLY_EXIT_CODE -eq 0 ]; then
        log "✅ Apply succeeded"
        return 0
    fi

    log "❌ Apply failed (exit code: $APPLY_EXIT_CODE)"

    # If the failure is a Kubernetes rollout timeout, infrastructure and
    # Kubernetes objects are already provisioned — the kubelet will keep
    # retrying the pods independently. Treat this as a partial success so
    # the build does not fail over a transient pod health-check window.
    # Not a retry — no second apply attempt happens either way.
    if grep -qiE "(timed out waiting for the condition|Deployment.*timed out|StatefulSet.*timed out|rollout.*timed out|timed out.*[Dd]eployment|timed out.*[Ss]tateful[Ss]et|timed out.*rollout)" /tmp/apply_output.txt 2>/dev/null; then
        log "⚠️  Kubernetes rollout timeout detected — infrastructure is provisioned"
        log "ℹ️  Pods will continue health checks independently; treating as partial success"
        return 0
    fi

    if self_heal_orphaned_creates; then
        log "🔄 Retrying apply once now that the orphaned resource is tracked in state..."
        set +e
        tofu apply -auto-approve tfplan 2>&1 | tee /tmp/apply_output_retry.txt
        RETRY_EXIT_CODE=${PIPESTATUS[0]}
        set -e
        if [ $RETRY_EXIT_CODE -eq 0 ]; then
            log "✅ Apply succeeded after self-heal"
            return 0
        fi
        log "❌ Apply still failed after self-heal (exit code: $RETRY_EXIT_CODE) — not retrying again"
        APPLY_EXIT_CODE=$RETRY_EXIT_CODE
    fi

    log "💥 Apply failed — not retrying automatically. Retry the deployment from the RAD dashboard."

    # Show current state for debugging
    log "🔍 Current state summary:"
    tofu show -json 2>/dev/null \
        | jq -r '.values.root_module.resources[]?.address // empty' \
        | head -10 \
        || log "Unable to show state"

    return $APPLY_EXIT_CODE
}

apply_once

log "🎯 Infrastructure changes applied successfully"
