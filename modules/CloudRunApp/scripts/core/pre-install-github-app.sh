#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Pre-install Google Cloud Build GitHub App to avoid manual approval for each connection
# This script guides you through installing the app once at the organization level

set -euo pipefail

echo "════════════════════════════════════════════════════════════════════════"
echo "  Pre-Install Google Cloud Build GitHub App"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
echo "This one-time setup will allow all future Cloud Build connections to work"
echo "automatically without manual approval."
echo ""
echo "Steps:"
echo "  1. Visit: https://github.com/marketplace/google-cloud-build"
echo "  2. Click 'Install it for free' or 'Set up a plan'"
echo "  3. Select your organization or personal account"
echo "  4. Choose repositories:"
echo "     - 'All repositories' (recommended for full automation)"
echo "     - OR select specific repositories"
echo "  5. Click 'Install' to authorize"
echo ""
echo "After installation, note your installation ID:"
echo "  - Visit: https://github.com/settings/installations"
echo "  - Click 'Configure' next to 'Google Cloud Build'"
echo "  - Copy the installation ID from the URL (last number)"
echo "    Example: https://github.com/settings/installations/12345678"
echo "    Installation ID: 12345678"
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo ""
read -p "Press Enter after you've completed the installation..."
echo ""
read -p "Enter your GitHub App Installation ID: " INSTALL_ID

if [[ -z "$INSTALL_ID" || ! "$INSTALL_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid installation ID. Must be a number."
  exit 1
fi

echo ""
echo "✅ Installation ID: $INSTALL_ID"
echo ""
echo "Now update your Terraform variables:"
echo "  github_app_installation_id = \"$INSTALL_ID\""
echo "  github_token_secret_name   = null  # Don't use PAT if using App"
echo ""
echo "Future deployments will use this installation automatically!"
echo ""
