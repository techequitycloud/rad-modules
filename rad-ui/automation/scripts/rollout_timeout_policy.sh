#!/usr/bin/env bash
# When may a FAILED apply be reported as a success? (audit P-30, decision D-9)
#
# Sourced by apply_infrastructure.sh and apply_infrastructure_update.sh; it
# defines functions and runs nothing.
#
# A Kubernetes workload rollout that outlasts its wait is not a broken
# deployment: the Deployment/StatefulSet exists, the kubelet keeps retrying the
# pods, and a slow image pull or first-boot migration usually lands minutes
# later. Failing the build over that window is the wrong answer, so the
# pipeline has long treated a rollout timeout as partial success.
#
# The defect was HOW it recognised one: a single grep over the WHOLE apply
# output returned success whenever any rollout-style timeout appeared ANYWHERE
# -- whatever else had failed beside it. A Cloud SQL error plus an unrelated
# "timed out waiting for the condition" was reported as SUCCESS: the module fee
# was charged, and dependents were released onto a broken prerequisite.
#
# The rule now: tolerated ONLY when the apply printed at least one `Error:`
# block and EVERY block is a workload rollout timeout. A single other error --
# or no error block at all (OOM, a killed process) -- fails the build as before.
#
# When the tolerance is taken it is RECORDED, not just logged: the marker is
# written to the step's $BUILDER_OUTPUT/output, which Cloud Build publishes as
# results.buildStepOutputs on the build, and notification_status copies it onto
# the deployment's build record as rolloutTimeoutTolerated. A SUCCESS that was
# really "infrastructure up, pods still starting" is then distinguishable from
# a clean one after the fact.

ROLLOUT_TIMEOUT_MARKER="rolloutTimeoutTolerated"

# Print each `Error:` block of an OpenTofu log on ONE line, blocks separated by
# newlines. Handles the boxed form (╷ │ Error: … ╵) with or without ANSI colour,
# and the unboxed form, where a block runs until the next `Error:` or the end.
# `Warning:` blocks are not errors and are never emitted.
rollout_policy_error_blocks() {
    local log_file="$1" esc
    # The escape byte is built with printf, not written as \x1b: BusyBox and
    # BSD sed do not all understand that escape, and the pipeline image's sed
    # is not the one on a developer's laptop.
    esc=$(printf '\033')
    sed "s/${esc}\[[0-9;]*m//g" "$log_file" | awk '
        function flush() { if (inblock) { print buf; inblock = 0; buf = "" } }
        {
            line = $0
            sub(/^[[:space:]]*│[[:space:]]?/, "", line)
            stripped = line
            sub(/^[[:space:]]+/, "", stripped)
        }
        /^[[:space:]]*╵/ { flush(); next }
        stripped ~ /^Error:/ { flush(); inblock = 1; buf = stripped; next }
        stripped ~ /^Warning:/ { flush(); next }
        inblock { buf = buf " " stripped }
        END { flush() }
    '
}

# 0 when one block (already flattened to a line) is a workload rollout timeout.
#
# The signature is the one the tolerance has always meant: a "timed out" that
# names a Deployment, StatefulSet, DaemonSet or a rollout -- in practice
# `kubectl rollout status` / `kubectl wait` run from a provisioner, whose
# failure reads "error: timed out waiting for the condition on
# deployments/<name>". The whole-log grep this replaces matched the same
# phrasing, so the SET of tolerated messages is unchanged; what changed is that
# every other block must be one too.
#
# Deliberately NOT tolerated, although it is also a rollout that ran long: the
# kubernetes provider's own "Waiting for rollout to finish" / "StatefulSet …
# is not finished rolling out". The provider TAINTS a resource whose create
# fails that way, so the next apply destroys and recreates the workload.
# Reporting SUCCESS over a tainted resource would hide that replacement, and
# the old grep never matched those messages, so they fail as they always did.
#
# A JOB is never a rollout: a db-init or migration Job that times out means the
# application's data is not ready, which is exactly the broken prerequisite the
# tolerance must not paper over.
rollout_policy_is_rollout_block() {
    local block="$1"
    if printf '%s' "$block" | grep -qiE '(^|[^a-z])(cron)?jobs?([^a-z]|$)|kubernetes_(cron_)?job|jobs\.batch'; then
        return 1
    fi
    if printf '%s' "$block" | grep -qiE 'timed out' \
        && printf '%s' "$block" | grep -qiE 'deployment|stateful ?set|daemon ?set|rollout'; then
        return 0
    fi
    return 1
}

# 0 when the log holds at least one Error block and every one is a rollout
# timeout. Prints a one-line verdict for the build log either way.
only_rollout_timeouts() {
    local log_file="$1" blocks total=0 rollout=0 block
    [ -f "$log_file" ] || { echo "rollout policy: no apply log at $log_file"; return 1; }
    blocks=$(rollout_policy_error_blocks "$log_file")
    while IFS= read -r block; do
        [ -n "$block" ] || continue
        total=$((total + 1))
        if rollout_policy_is_rollout_block "$block"; then
            rollout=$((rollout + 1))
        else
            echo "rollout policy: not a rollout timeout -> ${block:0:240}"
        fi
    done <<< "$blocks"
    echo "rollout policy: $rollout of $total error block(s) are workload rollout timeouts"
    [ "$total" -gt 0 ] && [ "$rollout" -eq "$total" ]
}

# Record that the tolerance was taken, where notification_status can read it.
record_rollout_timeout_tolerated() {
    if [ -n "${BUILDER_OUTPUT:-}" ] && mkdir -p "$BUILDER_OUTPUT" 2>/dev/null; then
        printf '%s\n' "$ROLLOUT_TIMEOUT_MARKER" >> "$BUILDER_OUTPUT/output" \
            || echo "rollout policy: could not write $BUILDER_OUTPUT/output"
    fi
    # Also in the build log, greppable, for anyone reading the build directly.
    echo "RAD_BUILD_MARKER ${ROLLOUT_TIMEOUT_MARKER}=true"
}
