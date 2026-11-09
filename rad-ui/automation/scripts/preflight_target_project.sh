#!/usr/bin/env bash
# Preflight: is the TARGET project deployable at all, before `tofu plan`?
#
# Run by the create and update pipelines' plan step, from the module directory
# (where terraform.tfvars.json sits), immediately before `tofu plan`. NOT run
# by destroy or purge: a teardown must never be refused because the thing it is
# tearing down has lost billing or access.
#
# Why: a project with billing off, a bring-your-own project the deploy identity
# was never granted, or a project pending deletion all fail the same way today
# -- after init, plan and minutes of apply, as a wall of Terraform 403s that
# reads as a RAD bug. Each has a one-line cause and a one-line fix, and both
# are knowable in a few seconds before anything runs.
#
# ── Output contract (for the webapp / notification_status) ─────────────────
#
#   On a DEFINITIVE problem, exactly one line, then exit 1:
#
#     RAD_PREFLIGHT_FAILED: <CODE>: <human message including the exact fix command>
#
#   CODE is one of (stable; add, never rename):
#     PROJECT_NOT_ACCESSIBLE  the deploy identity cannot see the project: it does
#                             not exist, the id is mistyped, or no role is granted
#     PROJECT_NOT_ACTIVE      the project exists but is not ACTIVE
#                             (e.g. DELETE_REQUESTED -- it is being deleted)
#     BILLING_DISABLED        the project has no billing account / billing is off
#     IAM_PERMISSION_MISSING  the deploy identity lacks the permissions every
#                             module needs (see PERMISSIONS below)
#
#   Anything the preflight could not determine prints
#     RAD_PREFLIGHT_WARNING: <what could not be checked>
#   and exits 0. A passing preflight prints `RAD_PREFLIGHT_OK: <project>`, a
#   skipped one `RAD_PREFLIGHT_SKIPPED: <reason>`. Match on the prefix at the
#   start of a line; the message after the second colon is free text.
#
# ── FAILS OPEN ──────────────────────────────────────────────────────────────
# A false block is worse than the status quo (a slow, ugly failure), so this
# exits non-zero ONLY on an answer Google gave definitively: a 200 saying
# billing is off or a permission is absent, a 200 with a non-ACTIVE state, or a
# plain IAM 403/404 on the project itself. A token it cannot mint, a network
# error, a 5xx, a disabled API on the QUOTA project, a VPC-SC denial, an
# unparseable response, or a module shape it does not recognise all warn and
# continue. Set RAD_PREFLIGHT=off in the step's environment to skip it.
#
# ── Which project, and is it created by THIS build? ─────────────────────────
# The target is `project_id` from terraform.tfvars.json (every module's name
# for its destination project; `existing_project_id` as a fallback). It is
# skipped when this same build may create that project: any module declaring a
# `create_project` variable (Project_GCP) unless tfvars sets it to false, or
# tfvars setting create_project=true for any module. A chain member whose
# project an EARLIER deployment creates (Services_GCP and the app behind
# Project_GCP) needs no special case: the webapp holds it in WAITING until
# that prerequisite has SUCCEEDED, so its project exists by the time it plans.
#
# ── Whose permissions? ──────────────────────────────────────────────────────
# The provider's, not the build's: modules impersonate
# `resource_creator_identity` into the tenant project, and the build's own
# identity has no standing access there. So every call is made with a token
# minted for that identity -- from tfvars, else the module's variable default.
# An empty identity means the module runs on ambient credentials, and so does
# this. A declared identity whose default cannot be parsed skips the preflight
# rather than testing the wrong principal.

set -u

log() { echo "[$(date +'%H:%M:%S')] $1"; }
skip() { echo "RAD_PREFLIGHT_SKIPPED: $1"; exit 0; }
warn_continue() { echo "RAD_PREFLIGHT_WARNING: $1 — continuing without this check"; }
fail() { echo "RAD_PREFLIGHT_FAILED: $1: $2"; exit 1; }

# Every module enables its own APIs (google_project_service), creates its own
# service accounts and grants them project roles. All four are held by
# roles/owner (what a bring-your-own project is told to grant) and by the
# bundle Project_GCP grants in a RAD-managed project (editor +
# projectIamAdmin + serviceAccountAdmin). Only serviceusage.services.enable
# -- or holding NONE of them -- is treated as definitive; a partial set is a
# warning, because a deliberately custom role may still cover what one
# particular module needs.
PERMISSIONS='["serviceusage.services.enable","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","iam.serviceAccounts.create"]'

CRM="https://cloudresourcemanager.googleapis.com"
BILLING="https://cloudbilling.googleapis.com"

[ "${RAD_PREFLIGHT:-on}" = "off" ] && skip "disabled (RAD_PREFLIGHT=off)"
command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v gcloud >/dev/null 2>&1 \
    || skip "jq, curl or gcloud is not available in this image"

TFVARS="terraform.tfvars.json"
[ -f "$TFVARS" ] || skip "no $TFVARS in $(pwd)"
jq -e 'type == "object"' "$TFVARS" >/dev/null 2>&1 || skip "$TFVARS is not a JSON object"

PROJECT=$(jq -r '(.project_id // .existing_project_id // "") | strings' "$TFVARS")
[ -n "$PROJECT" ] || skip "no project_id in $TFVARS"

# Does this module declare variable "<name>"? (any *.tf in the module root)
declares_var() { grep -qsE "^[[:space:]]*variable[[:space:]]+\"$1\"" ./*.tf; }

# The string default of variable "<name>", or nothing. Reads only the variable's
# own block, to its closing brace at column 0.
var_default() {
    awk -v name="$1" '
        $0 ~ "^[[:space:]]*variable[[:space:]]+\"" name "\"" { inblk = 1; next }
        inblk && /^}/ { exit }
        inblk && /^[[:space:]]*default[[:space:]]*=/ {
            if (match($0, /"[^"]*"/)) { print substr($0, RSTART + 1, RLENGTH - 2); found = 1 }
            exit
        }
        END { if (!found) exit 1 }
    ' ./*.tf 2>/dev/null
}

CREATE=$(jq -r 'if has("create_project") then (.create_project | tostring) else "unset" end' "$TFVARS")
if [ "$CREATE" = "true" ]; then
    skip "create_project=true — this build creates $PROJECT"
fi
if declares_var create_project && [ "$CREATE" != "false" ]; then
    skip "module declares create_project and tfvars does not set it to false — this build may create $PROJECT"
fi

if jq -e 'has("resource_creator_identity")' "$TFVARS" >/dev/null 2>&1; then
    IDENTITY=$(jq -r '.resource_creator_identity // "" | strings' "$TFVARS")
elif declares_var resource_creator_identity; then
    IDENTITY=$(var_default resource_creator_identity) \
        || skip "cannot resolve resource_creator_identity's default; not testing a different principal"
else
    IDENTITY=""
fi

log "🛫 Preflight for project $PROJECT (identity: ${IDENTITY:-ambient build credentials})"

if [ -n "$IDENTITY" ]; then
    TOKEN=$(gcloud auth print-access-token --impersonate-service-account="$IDENTITY" --quiet 2>/dev/null)
    WHO="serviceAccount:$IDENTITY"
else
    TOKEN=$(gcloud auth print-access-token --quiet 2>/dev/null)
    WHO_ACCOUNT=$(gcloud config get-value account --quiet 2>/dev/null)
    case "$WHO_ACCOUNT" in
        *gserviceaccount.com) WHO="serviceAccount:$WHO_ACCOUNT" ;;
        ?*) WHO="user:$WHO_ACCOUNT" ;;
        *) WHO="<deploying identity>" ;;
    esac
fi
if [ -z "$TOKEN" ]; then
    warn_continue "could not mint an access token for ${IDENTITY:-the build identity}"
    exit 0
fi

GRANT_FIX="gcloud projects add-iam-policy-binding $PROJECT --member=$WHO --role=roles/owner"
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

# call METHOD URL [DATA] -> prints the HTTP status, body in $BODY; "000" on a
# transport failure (curl's own -w value then). The token goes in a header read
# from stdin, never argv, so it cannot surface in a process listing.
call() {
    local method="$1" url="$2" data="${3:-}" code
    local args=(-sS -o "$BODY" -w '%{http_code}' --max-time 20 -X "$method" -H @-)
    [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "$data")
    : > "$BODY"
    code=$(printf 'Authorization: Bearer %s\n' "$TOKEN" | curl "${args[@]}" "$url" 2>/dev/null)
    printf '%s' "${code:-000}"
}

# 0 when an error body is a PLAIN IAM denial / not-found about the project
# itself, rather than about the caller's quota project, scopes or a perimeter
# (SERVICE_DISABLED, USER_PROJECT_DENIED, ACCESS_TOKEN_SCOPE_INSUFFICIENT,
# SECURITY_POLICY_VIOLATED ... all carry an ErrorInfo reason; a plain denial
# carries none, or IAM_PERMISSION_DENIED).
plain_denial() {
    local status reasons
    status=$(jq -r '.error.status // empty' "$BODY" 2>/dev/null) || return 1
    case "$status" in PERMISSION_DENIED|NOT_FOUND) ;; *) return 1 ;; esac
    reasons=$(jq -r '[.error.details[]? | .reason? // empty] | map(select(. != "IAM_PERMISSION_DENIED")) | length' "$BODY" 2>/dev/null) || return 1
    [ "$reasons" = "0" ]
}

# ── (a) the project exists, is visible to the identity, and is ACTIVE ───────
code=$(call GET "$CRM/v1/projects/$PROJECT")
case "$code" in
    200)
        state=$(jq -r '.lifecycleState // empty' "$BODY" 2>/dev/null)
        if [ -n "$state" ] && [ "$state" != "ACTIVE" ]; then
            fail PROJECT_NOT_ACTIVE "Project $PROJECT is $state, not ACTIVE. If it was deleted by mistake, restore it within 30 days: gcloud projects undelete $PROJECT — otherwise deploy into a different project."
        fi
        ;;
    403|404)
        if plain_denial; then
            fail PROJECT_NOT_ACCESSIBLE "Project $PROJECT does not exist or $WHO has no access to it. Check the project id is spelled correctly, then grant access: $GRANT_FIX"
        fi
        warn_continue "project lookup returned HTTP $code for a reason other than access ($(jq -r '.error.message // empty' "$BODY" 2>/dev/null | head -c 200))"
        exit 0
        ;;
    *)
        warn_continue "project lookup returned HTTP $code"
        exit 0
        ;;
esac

# ── (b) billing is enabled ──────────────────────────────────────────────────
code=$(call GET "$BILLING/v1/projects/$PROJECT/billingInfo")
if [ "$code" = "200" ]; then
    if [ "$(jq -r '.billingEnabled // false' "$BODY" 2>/dev/null)" != "true" ]; then
        fail BILLING_DISABLED "Billing is not enabled on project $PROJECT, so Google refuses to enable APIs or create resources in it. If RAD manages this project, buy credits in the RAD console (billing is suspended while your purchased credit balance is negative). Otherwise link a billing account: gcloud billing projects link $PROJECT --billing-account=XXXXXX-XXXXXX-XXXXXX"
    fi
else
    warn_continue "billing status unreadable (HTTP $code)"
fi

# ── (c) the identity holds the permissions every module needs ───────────────
code=$(call POST "$CRM/v1/projects/$PROJECT:testIamPermissions" "{\"permissions\":$PERMISSIONS}")
if [ "$code" = "200" ]; then
    missing=$(jq -r --argjson want "$PERMISSIONS" '($want - (.permissions // [])) | join(",")' "$BODY" 2>/dev/null)
    held=$(jq -r '(.permissions // []) | length' "$BODY" 2>/dev/null)
    if [ -n "$missing" ]; then
        case ",$missing," in
            *,serviceusage.services.enable,*)
                fail IAM_PERMISSION_MISSING "$WHO lacks $missing on project $PROJECT, which every RAD module needs. Grant it: $GRANT_FIX" ;;
        esac
        if [ "$held" = "0" ]; then
            fail IAM_PERMISSION_MISSING "$WHO lacks $missing on project $PROJECT, which every RAD module needs. Grant it: $GRANT_FIX"
        fi
        echo "RAD_PREFLIGHT_WARNING: $WHO lacks $missing on project $PROJECT; this module may fail if it needs them. Fix: $GRANT_FIX"
    fi
else
    warn_continue "permission test unreadable (HTTP $code)"
fi

echo "RAD_PREFLIGHT_OK: $PROJECT"
exit 0
