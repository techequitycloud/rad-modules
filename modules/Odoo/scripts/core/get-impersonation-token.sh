#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Script to get an access token for service account impersonation

set -e

SERVICE_ACCOUNT="$1"

if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "{\"access_token\": \"\"}" >&2
  exit 0
fi

# Get access token for impersonation
ACCESS_TOKEN=$(gcloud auth print-access-token --impersonate-service-account="$SERVICE_ACCOUNT" 2>/dev/null || echo "")

# Return JSON output
cat <<EOF
{
  "access_token": "$ACCESS_TOKEN"
}
EOF
