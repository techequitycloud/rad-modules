#!/bin/bash
# set -x 

PROJECT_ID=$1
REGION=$2
SERVICE_ACCOUNT=$3

if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

# List all zones in the specified region
ZONES=$(gcloud compute zones list --project="${PROJECT_ID}" --filter="region:($REGION)" --format="value(name)" $SA_ARG)

# Initialize variables to hold instance information
INSTANCE_INFO=""

# Search for the instance with a name starting with "nfsserver"
INSTANCE_INFO=$(gcloud compute instances list --project="${PROJECT_ID}" --filter="name~'^nfsserver' AND zone:(${ZONES})" --format="json" $SA_ARG | jq -r '.[] | {name: .name, zone: .zone, internalIP: .networkInterfaces[0].networkIP}')

# Combine results
echo '{'
echo '"gce_instance_name": "'$(echo "$INSTANCE_INFO" | jq -r '.name')'",'
echo '"gce_instance_zone": "'$(echo "$INSTANCE_INFO" | jq -r '.zone')'",'
echo '"gce_instance_internalIP": "'$(echo "$INSTANCE_INFO" | jq -r '.internalIP')'"'
echo '}'

