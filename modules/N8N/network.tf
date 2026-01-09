# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

########################################################################################
# Use external data source to check network and subnet existence
########################################################################################

data "external" "check_network" {
  program = ["bash", "-c", <<-EOT
    set -e
    PROJECT_ID="${var.existing_project_id}"  # ✅ FIXED: Use variable instead of local
    NETWORK_NAME="${var.network_name}"
    
    # Use the pre-determined impersonation service account
    if [ -n "${local.impersonation_service_account}" ]; then
      SA_ARG="--impersonate-service-account=${local.impersonation_service_account}"
      >&2 echo "Using impersonation service account: ${local.impersonation_service_account}"
    else
      SA_ARG=""
      >&2 echo "No service account impersonation"
    fi
    
    # Check if VPC network exists
    if gcloud compute networks describe "$NETWORK_NAME" --project="$PROJECT_ID" $SA_ARG >/dev/null 2>&1; then
      NETWORK_EXISTS="true"
      
      # Get subnets information with better error handling
      SUBNETS_JSON=$(gcloud compute networks subnets list \
        --filter="network:$NETWORK_NAME" \
        --project="$PROJECT_ID" \
        --format="json" \
        $SA_ARG 2>/dev/null || echo "[]")
      
      if [ "$SUBNETS_JSON" != "[]" ] && [ -n "$SUBNETS_JSON" ]; then
        # Extract information safely and convert to JSON strings
        REGIONS=$(echo "$SUBNETS_JSON" | jq -r '.[].region // empty' | sed 's|.*/||' | sort -u | jq -R . | jq -s . | jq -c .)
        SUBNET_NAMES=$(echo "$SUBNETS_JSON" | jq -r '.[].name // empty' | sort | jq -R . | jq -s . | jq -c .)
        SUBNET_CIDRS=$(echo "$SUBNETS_JSON" | jq -r '.[].ipCidrRange // empty' | sort | jq -R . | jq -s . | jq -c .)
        SUBNET_DETAILS=$(echo "$SUBNETS_JSON" | jq -c '[.[] | {name: (.name // ""), region: ((.region // "") | split("/")[-1]), cidr: (.ipCidrRange // "")}]')
        SUBNET_COUNT=$(echo "$SUBNETS_JSON" | jq 'length')
      else
        REGIONS="[]"
        SUBNET_NAMES="[]"
        SUBNET_CIDRS="[]"
        SUBNET_DETAILS="[]"
        SUBNET_COUNT="0"
      fi
    else
      NETWORK_EXISTS="false"
      REGIONS="[]"
      SUBNET_NAMES="[]"
      SUBNET_CIDRS="[]"
      SUBNET_DETAILS="[]"
      SUBNET_COUNT="0"
    fi
    
    # Escape quotes in JSON strings for proper embedding
    REGIONS_ESCAPED=$(echo "$REGIONS" | sed 's/"/\\"/g')
    SUBNET_NAMES_ESCAPED=$(echo "$SUBNET_NAMES" | sed 's/"/\\"/g')
    SUBNET_CIDRS_ESCAPED=$(echo "$SUBNET_CIDRS" | sed 's/"/\\"/g')
    SUBNET_DETAILS_ESCAPED=$(echo "$SUBNET_DETAILS" | sed 's/"/\\"/g')
    
    # Output JSON with all values as strings
    cat <<EOF
{
  "network_exists": "$NETWORK_EXISTS",
  "regions": "$REGIONS_ESCAPED",
  "subnet_names": "$SUBNET_NAMES_ESCAPED",
  "subnet_cidrs": "$SUBNET_CIDRS_ESCAPED",
  "subnet_details": "$SUBNET_DETAILS_ESCAPED",
  "subnet_count": "$SUBNET_COUNT"
}
EOF
  EOT
  ]
  
  # ✅ ADDED: Explicit dependency
  depends_on = [
    data.google_project.existing_project
  ]
}

########################################################################################
# Local variables for network resources
########################################################################################

locals {
  network_exists = data.external.check_network.result.network_exists == "true"
  
  # ✅ FIXED: Safe parsing with fallback
  discovered_regions_raw = try(jsondecode(data.external.check_network.result.regions), [])
  
  # Filter out invalid regions
  discovered_regions = [
    for region in local.discovered_regions_raw : region
    if region != null && region != ""
  ]
  
  # ✅ CRITICAL: Always provide fallback to prevent empty list
  regions_list = length(local.discovered_regions) > 0 ? local.discovered_regions : ["us-central1"]
  
  # ✅ FIXED: Safe parsing for all fields
  subnet_names   = try(jsondecode(data.external.check_network.result.subnet_names), [])
  subnet_cidrs   = try(jsondecode(data.external.check_network.result.subnet_cidrs), [])
  subnet_details = try(jsondecode(data.external.check_network.result.subnet_details), [])
}

