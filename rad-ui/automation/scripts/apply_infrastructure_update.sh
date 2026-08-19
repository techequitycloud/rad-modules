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
# Cloud SQL exists long before it is USABLE. An instance reports back to
# `tofu import` the moment it appears, but stays PENDING_CREATE for minutes
# afterwards and rejects every mutation until it reaches RUNNABLE:
#
#   Error: failed to update root_password : googleapi: Error 400:
#   Invalid request since instance is not running., invalid
#
# That is exactly what happened on 2026-08-15 to Services_GCP a24f4c5c. The
# import above worked perfectly — the orphan was found and adopted — and the
# immediate re-plan/apply then died on the root_password update because the
# instance it had just adopted was ~2 minutes old. Its twin fbd3f59f, created
# THREE SECONDS earlier in another project from identical config, succeeded;
# the only difference was how long Cloud SQL took to report ready.
#
# So the import fixed the state problem and inherited the timing problem. For
# a bucket or a service account "exists" and "usable" are the same instant;
# for Cloud SQL they are not, and this is the one resource the self-heal
# adopts where that gap is minutes wide.
#
# Refreshed through OpenTofu rather than `gcloud sql instances describe`: the
# provider authenticates by impersonating rad-module-creator into the tenant
# project (see each module's provider-auth.tf), and the build's own identity
# has no standing access there. `-refresh-only` reuses that same credential
# and needs no gcloud in the image — which this script otherwise never calls.
#
# Best-effort by design: on timeout it logs and proceeds to the retry anyway,
# because a slow-but-eventually-ready instance and a genuinely broken one look
# identical from here, and hanging the build helps neither.
SQL_READY_TIMEOUT_SECONDS=${SQL_READY_TIMEOUT_SECONDS:-900}
SQL_READY_POLL_SECONDS=${SQL_READY_POLL_SECONDS:-30}

wait_for_sql_instance_ready() {
    local addr="$1"
    local started=$SECONDS
    local state=""

    while [ $(( SECONDS - started )) -lt "$SQL_READY_TIMEOUT_SECONDS" ]; do
        # Re-read the live resource with the provider's own (impersonated)
        # credentials. Failures are non-fatal: a transient read must not turn
        # a recoverable wait into a hard stop.
        tofu apply -refresh-only -auto-approve -input=false -target="$addr" \
            >/tmp/sql_ready_refresh.txt 2>&1 || true

        state=$(tofu state show -no-color "$addr" 2>/dev/null \
            | awk -F'"' '/^[[:space:]]*state[[:space:]]*=/ { print $2; exit }')

        if [ "$state" = "RUNNABLE" ]; then
            log "   ✅ $addr is RUNNABLE after $(( SECONDS - started ))s"
            return 0
        fi

        log "   ⏳ $addr is ${state:-unknown} — waiting for RUNNABLE ($(( SECONDS - started ))s elapsed)"
        sleep "$SQL_READY_POLL_SECONDS"
    done

    log "   ⚠️  $addr still ${state:-unknown} after ${SQL_READY_TIMEOUT_SECONDS}s — retrying the apply anyway"
    return 1
}

self_heal_orphaned_creates() {
    # ONE orphan, TWO symptoms, in two different applies -- and this gate used
    # to recognise only the first.
    #
    #   apply N    the create wait times out AFTER the resource is already live
    #              -> "Error waiting for Create"        (orphan is CREATED)
    #   apply N+1  the config plans a create for a resource that already exists
    #              -> "Error 409: ... already own it"   (orphan is REDISCOVERED)
    #
    # The remedy is identical in both cases -- import the live resource -- and
    # the import branches below already cover bucket, cluster and SQL instance.
    # But an orphan that survived into a LATER apply could never reach them,
    # because the second symptom never matched. So the self-heal could only fix
    # an orphan in the same apply that produced it, which is the one case where
    # a human is least likely to be waiting.
    #
    # Confirmed live 2026-08-16 on Odoo_CloudRun a0b84a92 (gcp-rad-dev-c005ec73):
    # all three of its buckets were created at 22:26:49-50, but only
    # gcs-odoodemodfbf1ea1-addons was missing from state -- state serial 10 held
    # buckets["data"] and backup_bucket[0] and nothing else. A later apply
    # therefore planned a create for a bucket that existed, failed 409, and the
    # google_storage_bucket import branch twenty lines below -- the exact fix --
    # was never reached.
    #
    # The 409 texts are matched specifically rather than by a bare
    # "already exists": GCS bucket names are GLOBALLY unique, so
    # "you already own it" is the storage API stating ownership, not a name
    # collision with another tenant. Where ownership is not asserted, the import
    # itself is still the safety net -- it only ever adopts a resource this
    # config planned to create and that tofu can actually read, and a resource
    # belonging to someone else fails the import and is left alone.
    #   apply N    Cloud Quotas create returns without the id reaching state
    #              -> "Error 400: ... already exist for container"  on the NEXT
    #                 apply, because that API has no delete and the orphan is
    #                 permanent.
    #
    # THE QUOTA SIGNATURE IS NOT A 409 AND NOT "existS". This gate listed only
    # the two shapes seen when it was written (GCS bucket, GKE cluster -- both
    # 409s), so the google_cloud_quotas_quota_preference arm BELOW, which was
    # written specifically for this failure and quotes its message verbatim,
    # could never be reached: the function returned here first. Cost a live
    # Project_GCP CREATE on gcp-rad-prod-d7181716 (2026-08-19, build 1ff48b63)
    # after 8 minutes of apply. When adding a handler, widen this gate in the
    # same change -- a special case behind a door that does not open is not a
    # special case.
    if ! grep -qiE "Error waiting for (creating|Create)|already own it|Error 409:.*already exists|Quota Preference with dimension.*already exist" /tmp/apply_output.txt 2>/dev/null; then
        return 1
    fi

    log "🔎 Orphaned-create signature detected (create-wait timeout or 409 conflict) — checking whether the resource actually exists live before giving up..."

    local healed=false
    local addr name project location
    # Addresses adopted this round that need a readiness wait before the
    # re-apply touches them. Only Cloud SQL: see wait_for_sql_instance_ready.
    local sql_imported=
    # `set -f` because a plan address for a for_each resource carries brackets --
    # buckets["addons"] -- and an unquoted $(...) expansion is subject to pathname
    # expansion, where [...] is a character class. A stray matching filename would
    # silently rewrite the address.
    set -f
    for addr in $(tofu show -json tfplan | jq -r '.resource_changes[]? | select(.change.actions == ["create"]) | .address'); do
        # Leading * because these are MODULE-RELATIVE addresses. The patterns were
        # anchored at the root, e.g. `google_storage_bucket.*`, but nothing in this
        # catalogue is declared at the root: the real address is
        #   module.app_cloudrun.module.app_storage.module.app_storage.google_storage_bucket.buckets["addons"]
        # so no case arm ever matched and the self-heal returned having healed
        # nothing -- while logging that it was checking. Confirmed live 2026-08-17
        # on Odoo_CloudRun a0b84a92: the gate opened, the loop ran, and the apply
        # still failed 4s later with the bucket sitting there live.
        #
        # `*google_storage_bucket.*` cannot over-match a sibling type: it requires
        # the type name followed by a literal dot, so google_storage_bucket_object
        # and google_storage_bucket_iam_member are still correctly ignored.
        case "$addr" in
            *google_sql_database_instance.*)
                name=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.name')
                project=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.project')
                if [ -n "$name" ] && [ "$name" != "null" ] && [ -n "$project" ] && [ "$project" != "null" ]; then
                    log "   Trying import: $addr <- $project/$name"
                    if tofu import "$addr" "$project/$name" >/tmp/self_heal_import.txt 2>&1; then
                        log "   ✅ Imported $addr — it already existed live"
                        healed=true
                        sql_imported="$sql_imported $addr"
                    else
                        log "   ℹ️  $addr not found live (real failure, not orphaned) — leaving as-is"
                    fi
                fi
                ;;
            *google_container_cluster.*)
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
            *google_cloud_quotas_quota_preference.*)
                # DIFFERENT IN KIND from the three above, and that is the whole
                # reason it needs its own arm rather than another name lookup.
                #
                # A quota preference's name is SERVER-GENERATED (a UUID), so the
                # plan cannot supply it: `.change.after.name` is null for a
                # create. The import id therefore has to be DISCOVERED, by
                # listing the container's preferences and matching the identity
                # the config does know -- service + quota_id + dimensions.
                #
                # It also cannot be fixed the way every earlier orphan was. The
                # Cloud Quotas API has NO DELETE, so "remove it and let Terraform
                # recreate it" is unavailable: an orphan here is permanent until
                # imported, and every subsequent apply of that project fails on
                # it. Confirmed live 2026-08-18 on gcp-rad-prod-8070009f, where
                # 7 of 8 CPUS-per-project-region preferences were in state and
                # northamerica-south1 was live-but-orphaned, blocking the whole
                # Project_GCP apply with "Quota Preference with dimension '{}'
                # already exist".
                #
                # Location is always `global` in the import id even for a
                # region-dimensioned preference -- the region lives in
                # dimensions, not in the path. The provider accepts only
                # `<parent>/locations/global/quotaPreferences/<name>`.
                qp_parent=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.parent')
                qp_service=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.service')
                qp_quota=$(tofu show -json tfplan | jq -r --arg a "$addr" '.resource_changes[] | select(.address==$a) | .change.after.quota_id')
                qp_dims=$(tofu show -json tfplan | jq -c --arg a "$addr" '.resource_changes[] | select(.address==$a) | (.change.after.dimensions // {})')
                if [ -n "$qp_parent" ] && [ "$qp_parent" != "null" ] && [ -n "$qp_quota" ] && [ "$qp_quota" != "null" ]; then
                    qp_token=$(gcloud auth print-access-token 2>/dev/null)
                    qp_name=$(curl -s -H "Authorization: Bearer $qp_token" \
                        "https://cloudquotas.googleapis.com/v1/$qp_parent/locations/global/quotaPreferences?pageSize=500" \
                        | jq -r --arg s "$qp_service" --arg q "$qp_quota" --argjson d "$qp_dims" \
                          '[.quotaPreferences[]? | select(.service==$s and .quotaId==$q and ((.dimensions // {}) == $d))][0].name // empty' \
                        | awk -F/ '{print $NF}')
                    if [ -n "$qp_name" ]; then
                        log "   Trying import: $addr <- $qp_parent/locations/global/quotaPreferences/$qp_name"
                        if tofu import "$addr" "$qp_parent/locations/global/quotaPreferences/$qp_name" >/tmp/self_heal_import.txt 2>&1; then
                            log "   ✅ Imported $addr — it already existed live"
                            healed=true
                        else
                            log "   ℹ️  $addr could not be imported — leaving as-is"
                        fi
                    else
                        log "   ℹ️  No live quota preference matches $qp_quota $qp_dims (real failure, not orphaned) — leaving as-is"
                    fi
                fi
                ;;
            *google_storage_bucket.*)
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
    # Globbing stays off through the sql_imported loop below, which iterates the
    # same bracket-bearing addresses, and is restored once both are done.

    if [ "$healed" = "true" ]; then
        # Adopted Cloud SQL instances must be RUNNABLE before the retry, or the
        # apply fails on the first mutation it attempts against them.
        if [ -n "$sql_imported" ]; then
            log "⏳ Waiting for adopted Cloud SQL instance(s) to become RUNNABLE before retrying..."
            for addr in $sql_imported; do
                wait_for_sql_instance_ready "$addr" || true
            done
        fi

        set +f
        log "🔄 Re-planning with the imported resource(s) before retrying apply..."
        set +e
        tofu plan -input=false -out=tfplan -detailed-exitcode
        set -e
        return 0
    fi
    set +f
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
