#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Automatically approve Google Cloud Build GitHub App installation using gh CLI
# This script uses GitHub's API to programmatically approve pending installations

set -euo pipefail

GH_TOKEN="${GH_TOKEN:-}"
GH_ORG="${1:-}"
CONNECTION_INSTALL_URL="${2:-}"

if ! command -v gh &> /dev/null; then
  echo "❌ ERROR: GitHub CLI (gh) is not installed"
  echo ""
  echo "Install it with:"
  echo "  - macOS: brew install gh"
  echo "  - Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
  echo "  - Or download from: https://cli.github.com/"
  exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
  if [[ -n "$GH_TOKEN" ]]; then
    echo "Authenticating with GH_TOKEN..."
    echo "$GH_TOKEN" | gh auth login --with-token
  else
    echo "❌ ERROR: Not authenticated with GitHub CLI"
    echo ""
    echo "Authenticate using ONE of these methods:"
    echo "  1. Interactive: gh auth login"
    echo "  2. Token: export GH_TOKEN='your_token' (must have admin:org scope)"
    exit 1
  fi
fi

echo "Checking for pending GitHub App installations..."
echo ""

# Get the Google Cloud Build app slug
APP_SLUG="google-cloud-build"

# Method 1: If we have the installation URL from the connection
if [[ -n "$CONNECTION_INSTALL_URL" ]]; then
  echo "Opening installation URL in browser..."
  echo "URL: $CONNECTION_INSTALL_URL"

  # Try to open the URL automatically
  if command -v xdg-open &> /dev/null; then
    xdg-open "$CONNECTION_INSTALL_URL"
  elif command -v open &> /dev/null; then
    open "$CONNECTION_INSTALL_URL"
  else
    echo "Please open this URL manually: $CONNECTION_INSTALL_URL"
  fi

  echo ""
  echo "After approving in the browser, the connection will complete automatically."
  exit 0
fi

# Method 2: Find and approve pending installations via API
if [[ -n "$GH_ORG" ]]; then
  echo "Checking organization: $GH_ORG"

  # Get pending installation requests
  PENDING=$(gh api "/orgs/$GH_ORG/installation" 2>/dev/null | jq -r '.app_slug // empty')

  if [[ "$PENDING" == "$APP_SLUG" ]]; then
    echo "✅ Found pending installation for $APP_SLUG"

    # Get installation ID
    INSTALL_ID=$(gh api "/orgs/$GH_ORG/installation" | jq -r '.id')

    echo "Installation ID: $INSTALL_ID"
    echo ""
    echo "To complete installation, run:"
    echo "  gh api --method PUT /app/installations/$INSTALL_ID -F accept=true"

    read -p "Approve now? (y/n): " APPROVE

    if [[ "$APPROVE" == "y" || "$APPROVE" == "Y" ]]; then
      gh api --method PUT "/app/installations/$INSTALL_ID" -F accept=true
      echo "✅ Installation approved!"
    fi
  else
    echo "No pending installations found for $APP_SLUG"
  fi
else
  echo "Usage: $0 [github_org] [connection_install_url]"
  echo ""
  echo "Examples:"
  echo "  $0 my-org"
  echo "  $0 '' 'https://github.com/apps/google-cloud-build/installations/new?state=...'"
fi
