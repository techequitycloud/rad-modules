#!/bin/bash
# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

PROJECT_ID="$1"
SECRET_NAME="$2"
INSTANCE_NAME="$3"
DB_USER="$4"
IMPERSONATE_SA="$5"

if [ -n "$IMPERSONATE_SA" ]; then
    SA_ARG="--impersonate-service-account=$IMPERSONATE_SA"
fi

echo "Managing database user $DB_USER for instance $INSTANCE_NAME in project $PROJECT_ID"

# 1. Check/Create Secret Version
echo "Checking secret $SECRET_NAME..."

# Check if secret exists first (Terraform should create the Secret resource, but we manage the version)
# We assume the Secret resource itself is managed by Terraform (it is in secrets.tf)

# Check if there is an enabled version
LATEST_VERSION=$(gcloud secrets versions list "$SECRET_NAME" --project="$PROJECT_ID" --filter="state:enabled" --format="value(name)" --limit=1 $SA_ARG 2>/dev/null || echo "")

PASSWORD=""

if [ -z "$LATEST_VERSION" ]; then
    echo "No active secret version found. Generating new password..."
    PASSWORD=$(openssl rand -base64 24)
    echo "Adding new version to secret $SECRET_NAME..."
    echo -n "$PASSWORD" | gcloud secrets versions add "$SECRET_NAME" --project="$PROJECT_ID" --data-file=- $SA_ARG >/dev/null
else
    echo "Secret version exists. Retrieving..."
    PASSWORD=$(gcloud secrets versions access latest --secret="$SECRET_NAME" --project="$PROJECT_ID" $SA_ARG)
fi

# 2. Manage SQL User
echo "Managing SQL user..."

# Check if user exists
USER_EXISTS=$(gcloud sql users list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" --format="value(name)" $SA_ARG 2>/dev/null | grep -x "$DB_USER" || echo "")

if [ -z "$USER_EXISTS" ]; then
    echo "User $DB_USER does not exist. Creating..."
    gcloud sql users create "$DB_USER" --instance="$INSTANCE_NAME" --project="$PROJECT_ID" --password="$PASSWORD" $SA_ARG
else
    echo "User $DB_USER exists. Updating password to match secret..."
    gcloud sql users set-password "$DB_USER" --instance="$INSTANCE_NAME" --project="$PROJECT_ID" --password="$PASSWORD" $SA_ARG
fi

echo "Database user setup complete."
