#!/bin/bash
set -e

# Fetch the access token from the metadata server
# We use a short timeout to fail fast if metadata server is not available (e.g. local testing)
ACCESS_TOKEN=$(curl -s --max-time 2 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | jq -r .access_token)

# Get Project ID and Region from Metadata
PROJECT_ID=$(curl -s --max-time 2 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")
ZONE=$(curl -s --max-time 2 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone")

# Zone format: projects/PROJECT_NUMBER/zones/REGION-ZONE_SUFFIX (e.g., projects/123/zones/us-central1-a)
# Extract the last part (ZONE name)
ZONE_NAME=${ZONE##*/}
# Extract Region (e.g., us-central1 from us-central1-a)
REGION=${ZONE_NAME%-*}

# Service Name from Env Var (Cloud Run sets K_SERVICE)
SERVICE_NAME=${K_SERVICE}

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ] && [ -n "$PROJECT_ID" ] && [ -n "$REGION" ] && [ -n "$SERVICE_NAME" ]; then
    echo "Attempting to fetch Cloud Run Service URL for service: $SERVICE_NAME in region: $REGION..."

    # The Cloud Run Admin API v2
    # GET https://run.googleapis.com/v2/projects/{project}/locations/{location}/services/{service}
    RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://run.googleapis.com/v2/projects/$PROJECT_ID/locations/$REGION/services/$SERVICE_NAME")

    SERVICE_URL=$(echo "$RESPONSE" | jq -r .uri)

    if [ -n "$SERVICE_URL" ] && [ "$SERVICE_URL" != "null" ]; then
        echo "Detected Service URL: $SERVICE_URL"
        export url="$SERVICE_URL"
    else
        echo "Failed to fetch Service URL from Cloud Run API. Using default or existing 'url' env var."
        # Don't print full response as it might be large or contain sensitive info, but print error if any
        echo "API Response URI was null or empty."
    fi
else
    echo "Missing metadata or K_SERVICE. Skipping URL detection."
    echo "PROJECT_ID: $PROJECT_ID, REGION: $REGION, SERVICE_NAME: $SERVICE_NAME"
fi

# Execute the original entrypoint
exec docker-entrypoint.sh "$@"
