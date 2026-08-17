#!/usr/bin/env bash
#
# handle_plan_cycle.sh — diagnose, and where possible recover from, a Terraform
# dependency cycle reported during `tofu plan`.
#
# WHY THIS IS A FILE AND NOT INLINE IN cloudbuild_deployment_update.yaml
# ---------------------------------------------------------------------
# Cloud Build caps a single step arg at 10,000 characters and rejects the ENTIRE
# build config above it — the build is never created, the deployment is marked
# INTERNAL_ERROR, and nothing appears in the Cloud Build console to inspect.
# That is a confusing failure to debug (it reads as a platform outage), and it
# is exactly what happened when this logic first shipped inline: the step went
# to 12,429 chars and every UPDATE for every module broke until it was reverted.
# Keep substantial logic here, where it costs the build config nothing.
#
# CONTRACT
#   argv:  $1 plan log (ANSI-stripped)  $2 module name  $3 deployment id
#          $4 deployment bucket id
#   cwd:   the module directory, already initialised, with `tfplan` present
#   exit:  0 -> recovered; `tfplan` is now valid and the caller should apply it
#          1 -> not recovered; the caller should fail the build as before
#
set -uo pipefail

PLAN_LOG="${1:-}"
MODULE_NAME="${2:-}"
DEPLOYMENT_ID="${3:-}"
BUCKET_ID="${4:-}"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# Only act on an actual cycle. Any other planning failure is not ours.
#
# -a because Terraform's escape bytes make grep treat the log as binary and
# suppress output. The caller strips ANSI first, but this stays defensive:
# Terraform colourises "Error:" SEPARATELY from the message after it, so the raw
# bytes read `ESC[31mError: ESC[0mESC[1mCycle: module...` and a grep for the
# literal "Error: Cycle" matches nothing at all.
if ! grep -qa "Error: Cycle" "$PLAN_LOG" 2>/dev/null; then
    exit 1
fi

log "🔎 Dependency cycle reported — re-running the plan with core debug to capture the EDGES..."

# A cycle names its MEMBERS but never the EDGE that closed it, and with 150+
# members that is not enough to act on — three separate fixes were derived from
# reading the member list and none of them broke the cycle. Terraform will say
# which edges it added, but only at core debug, which is far too noisy to run on
# every deployment. So it runs only here, only after a cycle has been reported,
# and costs a normal deployment nothing.
#
# TF_LOG_CORE, deliberately, NOT TF_LOG. Plain TF_LOG=debug also enables PROVIDER
# logging, which writes request and response bodies — that is how secret values
# end up in a build log. The graph is built by core; providers have nothing to
# say about it.
TF_LOG_CORE=debug \
TF_LOG_PROVIDER=off \
TF_LOG_PATH=/workspace/tf_cycle_debug.log \
    tofu plan -input=false -out=tfplan-cycle-debug >/dev/null 2>&1

if [ -s /workspace/tf_cycle_debug.log ]; then
    # Uploaded rather than only printed: the useful part is the reference graph,
    # far larger than a sensible number of inline lines. It lands beside this
    # deployment's own terraform.tfvars.json — inside a trust boundary that
    # already holds this deployment's variables — so it adds no new exposure.
    DEBUG_URI="gs://${BUCKET_ID}/build-logs/update/${MODULE_NAME}/${DEPLOYMENT_ID}/tf_cycle_debug.log"
    if gsutil -q cp /workspace/tf_cycle_debug.log "$DEBUG_URI" 2>/dev/null; then
        log "   Full graph log: $DEBUG_URI"
    else
        log "   ⚠️  Could not upload the graph log."
    fi

    # The two lines that actually identify a cause, from experience: a deposed
    # destroy edge is a create_before_destroy replacement bridging two
    # topologies, and is usually THE edge. Print those before the generic dump.
    log "   --- destroy edges (these close the cycle; 'deposed' is the usual culprit) ---"
    grep -a "DestroyEdgeTransformer" /workspace/tf_cycle_debug.log \
        | sed 's/.*DestroyEdgeTransformer[0-9]*: //' | sort -u | head -40 || true
    log "   --- end extract ---"
else
    log "   ⚠️  Core debug produced no log; the cycle may predate graph construction."
fi

# ---------------------------------------------------------------------------
# TWO-PHASE RECOVERY
# ---------------------------------------------------------------------------
# A feature toggle that SWAPS one set of resources for another (enabling Cloud
# Deploy trades app_service for app_service_cd — 13 base resources for 109
# staged ones) cannot always be expressed as a single acyclic graph: the creates
# wait on the destroys through the `dependencies` recorded in state, and the
# destroys wait back through the module's shared locals.
#
# Terraform does not need one graph. Applying the deletions first and re-planning
# produces two acyclic graphs, which is what -target exists for.
#
# SAFETY — the part that matters. Targets are read from the plan Terraform just
# produced, and ONLY entries whose action is exactly ["delete"] are taken. A
# replace (["delete","create"]) is deliberately excluded: targeting one would
# destroy a live resource and rely on a second apply to bring it back. So this
# destroys nothing the successful apply would not have destroyed — it changes
# WHEN, never WHAT.
#
# This is possible at all because Terraform writes the plan file even when it
# reports the cycle ("Saved the plan to: tfplan" appears AFTER the error), since
# the diff is generated before the APPLY graph is validated.
if [ ! -f tfplan ]; then
    log "   ℹ️  No plan file to recover from."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    log "   ⚠️  python3 unavailable; cannot read the plan to recover."
    exit 1
fi

tofu show -json tfplan > /workspace/tfplan.json 2>/dev/null || true

DELETE_TARGETS=$(python3 - <<'PY' 2>/dev/null || true
import json
try:
    plan = json.load(open("/workspace/tfplan.json"))
except Exception:
    raise SystemExit(0)
for rc in plan.get("resource_changes", []):
    if rc.get("change", {}).get("actions") == ["delete"]:
        print(rc["address"])
PY
)

DELETE_COUNT=$(printf '%s\n' "$DELETE_TARGETS" | grep -c . || true)

if [ "$DELETE_COUNT" -eq 0 ]; then
    log "   ℹ️  No pure deletions in the plan, so this cycle is not a topology"
    log "      swap and this recovery does not apply."
    exit 1
fi

# A runaway guard. The transition this was written for destroys 13; a different
# order of magnitude means the plan is not the one this handles, and a human
# should look before anything is destroyed automatically.
if [ "$DELETE_COUNT" -gt 40 ]; then
    log "   ⛔ $DELETE_COUNT deletions is beyond the expected range for a feature"
    log "      toggle. Refusing to auto-recover — please review the plan."
    exit 1
fi

log "   🔁 Applying $DELETE_COUNT deletion(s) first, then re-planning."
log "      These are deletions the full apply had already planned:"
printf '%s\n' "$DELETE_TARGETS" | sed 's/^/        - /'

TARGET_ARGS=()
while IFS= read -r ADDR; do
    [ -n "$ADDR" ] && TARGET_ARGS+=("-target=$ADDR")
done <<< "$DELETE_TARGETS"

tofu apply -input=false -auto-approve "${TARGET_ARGS[@]}" 2>&1 | tail -40
PHASE1_EXIT=${PIPESTATUS[0]}

if [ "$PHASE1_EXIT" -ne 0 ]; then
    log "   ❌ Teardown phase failed (exit $PHASE1_EXIT); not re-planning."
    exit 1
fi

log "   ✅ Teardown phase complete. Re-planning..."
tofu plan -input=false -out=tfplan -detailed-exitcode 2>&1 \
    | tee /workspace/plan_output_phase2.log
REPLAN_EXIT=${PIPESTATUS[0]}

if [ "$REPLAN_EXIT" -eq 0 ] || [ "$REPLAN_EXIT" -eq 2 ]; then
    log "   ✅ Re-plan succeeded — the cycle is resolved. Continuing."
    exit 0
fi

log "   ❌ Re-plan still failing (exit $REPLAN_EXIT)."
exit 1
