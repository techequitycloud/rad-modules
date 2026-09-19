#!/usr/bin/env bash
# Refuse to run a second build against one deployment's Terraform state, and
# only then clear a state lock a dead build left behind. (audit P-24)
#
# Usage (environment, because Cloud Build substitutions are not expanded inside
# a script file -- the step hands them over):
#   PROJECT_ID     Cloud Build project                       (required)
#   DEPLOYMENT_ID  the deployment this build acts on          (required)
#   BUILD_ID       this build's own id, excluded from the list (required)
#   LOCK_PATH      gs:// path of the deployment's default.tflock. Optional:
#                  when set, a leftover lock is removed AFTER the check passes.
#
# Exit 0: no older build for this deployment is running (and the lock, if any,
# was cleared). Exit 1: an older build is running -- this build must stop.
# Exit 2: the check itself could not be completed -- this build must stop.
#
# WHY IT EXISTS. Every pipeline cleared the state lock on the way in, because
# GCS-backend locks never expire and a hard-killed build (timeout, OOM, cancel)
# otherwise blocks every later build for that deployment. That was justified as
# "the webapp only starts a new build once the previous one is terminal", and
# on 2026-08-19 the premise failed: an UPDATE started while its CREATE was
# still applying, the update deleted the create's live lock as "stale", and
# both builds failed after 46 real resources had been built. Create and update
# gained an --ongoing check; destroy, which runs `tofu destroy` against the
# same state, did not, and neither did purge.
#
# FAILS CLOSED. The inline check it replaces ran
#   gcloud builds list … 2>/dev/null | awk … || true
# so when gcloud errored (permissions, quota, a transient 503) the list was
# simply empty, the check passed, and the lock was deleted anyway -- the exact
# outcome the check exists to prevent, triggered by the check being unable to
# look. An error here now stops the build (after a short retry), because a
# build that did not start can be retried from the dashboard and a corrupted
# state cannot be un-corrupted.
#
# THE OLDEST BUILD WINS. Refusing whenever ANY other build is live made two
# builds that started together (a retried trigger call, see deployment_destroy
# and deployment_purge) refuse EACH OTHER, so neither ran. Only a build that
# sees an OLDER one live refuses; the oldest proceeds. Ties on createTime fall
# back to comparing build ids so exactly one wins.
#
# `--ongoing` (QUEUED + WORKING), matched CLIENT-side: a server-side filter on
# substitutions._DEPLOYMENT_ID scans the whole build history (measured >150s),
# which inside a build step is a hang, not a check.
set -uo pipefail

GCLOUD="${GCLOUD:-gcloud}"
GSUTIL="${GSUTIL:-gsutil}"
LIST_LIMIT="${GUARD_LIST_LIMIT:-500}"
ATTEMPTS="${GUARD_ATTEMPTS:-3}"
RETRY_SLEEP="${GUARD_RETRY_SLEEP:-5}"

log() { echo "[$(date +'%H:%M:%S')] $1"; }

for v in PROJECT_ID DEPLOYMENT_ID BUILD_ID; do
    if [ -z "${!v:-}" ]; then
        log "❌ $v is not set -- cannot check for concurrent builds, refusing to continue"
        exit 2
    fi
done

list_ongoing() {
    "$GCLOUD" builds list \
        --project="$PROJECT_ID" \
        --ongoing \
        --format="value(id,substitutions._DEPLOYMENT_ID,createTime)" \
        --limit="$LIST_LIMIT"
}

LISTING="" ; ok=0
for attempt in $(seq 1 "$ATTEMPTS"); do
    if LISTING=$(list_ongoing 2>/tmp/guard_concurrent_build.err); then
        ok=1
        break
    fi
    log "⚠️  Listing ongoing builds failed (attempt $attempt of $ATTEMPTS): $(head -c 400 /tmp/guard_concurrent_build.err)"
    [ "$attempt" -lt "$ATTEMPTS" ] && sleep "$RETRY_SLEEP"
done
if [ "$ok" -ne 1 ]; then
    log "❌ Could not confirm that no other build is running for deployment $DEPLOYMENT_ID."
    log "   Stopping rather than risk two builds on one Terraform state. Retry the"
    log "   deployment from the RAD dashboard, or contact support if this persists."
    exit 2
fi

# A full page means the answer may be incomplete, and an incomplete "none" is
# the same fail-open this script exists to remove.
if [ "$(printf '%s\n' "$LISTING" | grep -c .)" -ge "$LIST_LIMIT" ]; then
    log "❌ $LIST_LIMIT or more builds are in progress, so the list may be incomplete."
    log "   Stopping rather than proceed on a partial answer. Retry shortly."
    exit 2
fi

# createTime is RFC 3339 with a variable-length fraction ("…:05Z",
# "…:05.4Z", "…:05.123456789Z"), which does not sort as text: "Z" sorts after
# ".", so a whole second would compare LATER than the same second plus a
# fraction. Normalised to a fixed nine-digit fraction before comparing.
NORM='function norm(t,  a, f) { sub(/Z$/, "", t); n = split(t, a, "."); f = (n > 1) ? a[2] : ""; while (length(f) < 9) f = f "0"; return a[1] "." substr(f, 1, 9) }'

SELF_CREATED=$(printf '%s\n' "$LISTING" | awk -F'\t' -v self="$BUILD_ID" "$NORM"' $1 == self { print norm($3); exit }')

OLDER=$(printf '%s\n' "$LISTING" | awk -F'\t' \
    -v d="$DEPLOYMENT_ID" -v self="$BUILD_ID" -v mine="$SELF_CREATED" "$NORM"'
    $2 == d && $1 != self && $1 != "" {
        t = norm($3)
        # Our own entry missing (not yet visible, or already past QUEUED in an
        # inconsistent read) means we cannot order ourselves: treat every
        # other live build as older, which refuses -- the safe direction.
        if (mine == "" || t < mine || (t == mine && $1 < self)) print $1 " (created " $3 ")"
    }')

if [ -n "$OLDER" ]; then
    log "❌ Another build for deployment $DEPLOYMENT_ID is already running:"
    printf '%s\n' "$OLDER" | while IFS= read -r b; do log "     $b"; done
    log "   Two builds share one Terraform state file, so running both corrupts"
    log "   the lock and fails them BOTH. Wait for that build to finish, then"
    log "   retry this deployment from the RAD dashboard."
    exit 1
fi

YOUNGER=$(printf '%s\n' "$LISTING" | awk -F'\t' -v d="$DEPLOYMENT_ID" -v self="$BUILD_ID" '$2 == d && $1 != self && $1 != "" { print $1 }')
if [ -n "$YOUNGER" ]; then
    log "ℹ️  A newer build for this deployment is live ($(echo $YOUNGER)); it will stop itself. Continuing."
else
    log "✅ No other build is running for deployment $DEPLOYMENT_ID"
fi

# Only now is a leftover lock provably stale: no older build for this
# deployment is live, so nothing that could legitimately hold it remains.
if [ -n "${LOCK_PATH:-}" ]; then
    if "$GSUTIL" -q stat "$LOCK_PATH" >/dev/null 2>&1; then
        log "⚠️  Found a leftover state lock from a previous build — clearing it"
        "$GSUTIL" rm "$LOCK_PATH" || log "⚠️  Failed to clear stale lock (may have already cleared itself)"
    fi
fi
exit 0
