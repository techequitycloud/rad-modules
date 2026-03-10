#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Wait for GitHub Cloud Build v2 connection to reach COMPLETE state
# This is necessary when using Personal Access Tokens (PAT) because
# the GitHub App installation requires manual approval on GitHub.

set -euo pipefail

PROJECT_ID="${1:-}"
LOCATION="${2:-}"
CONNECTION_NAME="${3:-}"
IMPERSONATION_SA="${4:-}"
MAX_WAIT_SECONDS="${5:-900}" # Default 15 minutes
POLL_INTERVAL="${6:-10}"     # Poll every 10 seconds

if [[ -z "$PROJECT_ID" || -z "$LOCATION" || -z "$CONNECTION_NAME" ]]; then
  echo "ERROR: Missing required arguments"
  echo "Usage: $0 <project_id> <location> <connection_name> [impersonation_sa] [max_wait_seconds] [poll_interval]"
  exit 1
fi

# Set up impersonation if provided
IMPERSONATION_FLAG=""
if [[ -n "$IMPERSONATION_SA" && "$IMPERSONATION_SA" != "null" ]]; then
  IMPERSONATION_FLAG="--impersonate-service-account=${IMPERSONATION_SA}"
fi

echo "Waiting for GitHub connection to complete installation..."
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo "Connection: $CONNECTION_NAME"

ELAPSED=0
INSTALLATION_STATE="UNKNOWN"

while [[ $ELAPSED -lt $MAX_WAIT_SECONDS ]]; do
  # Get the connection details
  CONNECTION_JSON=$(gcloud builds connections describe "$CONNECTION_NAME" \
    --project="$PROJECT_ID" \
    --region="$LOCATION" \
    --format=json \
    $IMPERSONATION_FLAG 2>/dev/null || echo "{}")

  # Extract installation state
  INSTALLATION_STATE=$(echo "$CONNECTION_JSON" | jq -r '.installationState.stage // "UNKNOWN"')

  echo "[${ELAPSED}s] Installation state: $INSTALLATION_STATE"

  if [[ "$INSTALLATION_STATE" == "COMPLETE" ]]; then
    echo "✅ GitHub connection is ready!"
    exit 0
  fi

  if [[ "$INSTALLATION_STATE" == "PENDING_INSTALL_APP" ]]; then
    if [[ $ELAPSED -eq 0 ]]; then
      # Extract installation URL from connection
      INSTALL_URL=$(echo "$CONNECTION_JSON" | jq -r '.installationState.actionUri // empty')

      echo ""
      echo "⚠️  MANUAL ACTION REQUIRED ⚠️"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "The GitHub App installation is pending approval."
      echo ""

      if [[ -n "$INSTALL_URL" ]]; then
        echo "Installation URL: $INSTALL_URL"
        echo ""

        # Try to auto-open the URL in browser
        if command -v xdg-open &> /dev/null; then
          echo "Opening installation URL in browser..."
          xdg-open "$INSTALL_URL" 2>/dev/null || true
        elif command -v open &> /dev/null; then
          echo "Opening installation URL in browser..."
          open "$INSTALL_URL" 2>/dev/null || true
        fi
      else
        echo "Please complete these steps:"
        echo "  1. Visit: https://console.cloud.google.com/cloud-build/connections"
        echo "  2. Select your project: $PROJECT_ID"
        echo "  3. Click on connection: $CONNECTION_NAME"
        echo "  4. Follow the link to authorize the GitHub App installation"
        echo "  5. Approve the installation on GitHub"
        echo ""
      fi

      echo "Waiting for you to complete the installation..."
      echo ""
      echo "💡 TIP: To avoid this manual step in the future:"
      echo "   - Pre-install the app: ./scripts/core/pre-install-github-app.sh"
      echo "   - Then use github_app_installation_id instead of PAT"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    fi
  fi

  if [[ "$INSTALLATION_STATE" == "UNKNOWN" || "$INSTALLATION_STATE" == "null" ]]; then
    echo "⚠️  Warning: Could not determine installation state. Connection may not exist yet."
  fi

  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo ""
echo "❌ ERROR: Timeout waiting for GitHub connection to complete"
echo "Installation state after ${MAX_WAIT_SECONDS}s: $INSTALLATION_STATE"
echo ""
echo "Troubleshooting:"
echo "  1. Check if the GitHub App installation was approved on GitHub"
echo "  2. Visit the connection in Cloud Console to see detailed status"
echo "  3. Verify the Personal Access Token has the correct permissions (repo, admin:repo_hook, workflow)"
echo ""
exit 1
