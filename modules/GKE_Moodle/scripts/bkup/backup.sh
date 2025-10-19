#!/bin/bash
#
# Copyright 2024 Tech Equity Ltd
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

# set -x 

# Get the current timestamp
timestamp=$(date +%Y%m%d%H%M%S)

# Export database password for pg_dump
export PGPASSWORD=${DB_PASSWORD}

# Create temp directory
mkdir -p /mnt/temp

# Perform the database dump
pg_dump --no-owner -h ${DB_HOST} -p 5432 -U ${DB_USER} -d ${DB_NAME} -f /mnt/temp/dump.sql || { echo "pg_dump failed"; exit 1; }

# Copy files to temp directory
cd /mnt/temp && cp -r ../{backup,cache,filestorage,localcache,muc,sessions,theme,trashdir} .

# Create backup file using the timestamp
zip -r /data/${DB_NAME}_${timestamp}.zip * && rm -rf /mnt/temp
