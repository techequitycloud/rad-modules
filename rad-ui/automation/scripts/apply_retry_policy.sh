#!/usr/bin/env bash
# Which failed applies are worth ONE more attempt?
#
# Sourced by apply_infrastructure.sh and apply_infrastructure_update.sh, AFTER
# rollout_timeout_policy.sh (it reuses rollout_policy_error_blocks to split the
# log into Error blocks). It defines functions and runs nothing.
#
# The apply budget was cut to a single attempt after the Medusa incident
# (2026-08-06): a blind retry re-ran a Kaniko build that had failed on an npm
# registry rate limit, failed identically, and turned a 13-minute failure into
# a 25-minute one. That reasoning still holds for the general case -- most
# failures are deterministic and a retry only bills more build minutes.
#
# What it gave up is the small class of failures that are NOT deterministic:
# Google's control plane answering 5xx/429, IAM and API enablement taking a
# minute or two to propagate after THIS apply granted or enabled them, an IAM
# policy etag race, a plan the state moved under. Those fail a fresh
# deployment, the user is told to retry from the dashboard, and the retry
# succeeds -- so the platform asked a human to do what a back-off would have.
#
# The rule: retry ONCE, and only when EVERY Error block in the failed apply
# matches an entry on the allowlist below. One block outside the list -- or no
# Error block at all (OOM, a killed process) -- means the build fails exactly
# as it did before. This is the same "every block, never any block" shape as
# rollout_timeout_policy.sh, for the same reason: a whole-log grep would retry
# a real failure because a transient one happened to sit beside it.
#
# Never transient, whatever else the block says:
#   - local-exec provisioner errors. These wrap a script's own exit status
#     (Kaniko builds, npm/pip installs, kubectl) -- the Medusa case. A 429 from
#     a package registry printed inside one is not Google's control plane.
#   - "already exist(s)" -- that is an orphaned create, which
#     self_heal_orphaned_creates handles by IMPORTING, not by retrying.
#   - quota EXCEEDED (as opposed to a per-minute RATE limit) -- a limit does
#     not lift in 75 seconds.

# Minimum spacing between the failed attempt and the retry. Long enough for
# IAM (typically < 60s) and service enablement to propagate; short enough that
# a retry which does not help costs little. Overridable for tests.
APPLY_RETRY_BACKOFF_SECONDS=${APPLY_RETRY_BACKOFF_SECONDS:-75}

# 0 when ONE flattened Error block (see rollout_policy_error_blocks) is on the
# transient allowlist. $2 is the whole apply log, for the entries that are only
# transient when this same apply did something that needs time to propagate.
# Each entry carries the reason it is safe to retry.
apply_retry_is_transient_block() {
    local block="$1" log_file="$2"

    # Hard exclusions first (see header).
    if printf '%s' "$block" | grep -qiE 'local-exec provisioner error|already exists?([^a-z]|$)|already own it'; then
        return 1
    fi

    # 1. Google API 5xx: googleapi: Error 500 / 502 / 503 / 504, or the
    #    backendError / internalError reasons that accompany them. A server-side
    #    failure says nothing about the request. 501 (Not Implemented) is
    #    deterministic and deliberately absent. The `googleapi:` prefix keeps
    #    an HTTP status printed by some other tool out of this entry.
    if printf '%s' "$block" | grep -qE 'googleapi: Error 50[0234]([^0-9]|$)|(^|[^a-zA-Z])(backendError|internalError)([^a-zA-Z]|$)'; then
        return 0
    fi

    # 2. Google API rate limit: googleapi: Error 429 / rateLimitExceeded /
    #    "per minute" quota metrics. A per-DAY limit does not recover within the
    #    back-off, so a block naming one is excluded.
    if printf '%s' "$block" | grep -qE 'googleapi: Error 429([^0-9]|$)|rateLimitExceeded|userRateLimitExceeded' \
        && ! printf '%s' "$block" | grep -qiE 'per day|per-day|daily'; then
        return 0
    fi

    # 3. 409 concurrency, NOT existence: "There were concurrent policy changes"
    #    (IAM etag race when several bindings land at once), ABORTED, or an
    #    operation already running on the same resource. The existence 409s were
    #    excluded above.
    if printf '%s' "$block" | grep -qE 'Error 409' \
        && printf '%s' "$block" | grep -qiE 'concurrent|aborted|operation .*(in progress|already running)|try again'; then
        return 0
    fi

    # 4. Saved plan is stale: the state moved under the saved plan (another
    #    writer, or a refresh). The re-plan before the retry is the fix.
    if printf '%s' "$block" | grep -qiE 'Saved plan is stale'; then
        return 0
    fi

    # 5. API enablement propagation: SERVICE_DISABLED / "has not been used in
    #    project N before or it is disabled" -- transient ONLY when this same
    #    apply enabled services (a google_project_service finished creating).
    #    Without that, the API is simply off and nothing will turn it on, so a
    #    retry would fail identically.
    if printf '%s' "$block" | grep -qE 'SERVICE_DISABLED|has not been used in project .* before or it is disabled'; then
        if grep -aqE 'google_project_service[^:]*: Creation complete' "$log_file" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    # 6. IAM propagation: a 403 permission denial, or a just-created service
    #    account reported as not existing -- transient ONLY when this same apply
    #    created IAM bindings or service accounts (`..._iam_member`,
    #    `..._iam_binding`, `google_service_account`: Creation complete), which
    #    is what takes a minute to propagate.
    #
    #    A denial of setIamPolicy/getIamPolicy is excluded even then: those are
    #    the STRUCTURAL gaps roles/editor has on nearly every resource type
    #    (pubsub topics, Cloud Run services, secrets -- see Project_GCP
    #    project.tf deploying_identity_bundle), they recur on every attempt, and
    #    they are exactly the persistent IAM errors a blind retry must not chase.
    #    So are servicenetworking addPeering and cloudquotas.quotas.update, the
    #    other two recorded there.
    if printf '%s' "$block" | grep -qiE "Error 403.*(Permission '[^']+' denied|does not have [^ ]+ (permission|access))|Service account [^ ]+ does not exist"; then
        if printf '%s' "$block" | grep -qiE 'IamPolicy|addPeering|cloudquotas\.quotas\.update'; then
            return 1
        fi
        if grep -aqE '(_iam_member|_iam_binding|google_service_account)[^:]*: Creation complete' "$log_file" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    return 1
}

# 0 when the failed apply in $1 holds at least one Error block and EVERY block
# is transient. Prints a one-line verdict (and each non-transient block) for
# the build log either way.
apply_failure_is_transient() {
    local log_file="$1" blocks total=0 transient=0 block
    [ -f "$log_file" ] || { echo "retry policy: no apply log at $log_file"; return 1; }
    blocks=$(rollout_policy_error_blocks "$log_file")
    while IFS= read -r block; do
        [ -n "$block" ] || continue
        total=$((total + 1))
        if apply_retry_is_transient_block "$block" "$log_file"; then
            transient=$((transient + 1))
        else
            echo "retry policy: not transient -> ${block:0:240}"
        fi
    done <<< "$blocks"
    echo "retry policy: $transient of $total error block(s) are transient"
    [ "$total" -gt 0 ] && [ "$transient" -eq "$total" ]
}
