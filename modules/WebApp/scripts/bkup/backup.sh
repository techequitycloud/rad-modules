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

#!/bin/bash

# Get the current timestamp
timestamp=$(date +%Y%m%d%H%M%S)

# Create temp directory
mkdir -p /mnt/temp

# Function to try PostgreSQL dump
try_pg_dump() {
    echo "Attempting PostgreSQL dump..."
    export PGPASSWORD=${DB_PASSWORD}
    pg_dump --no-owner -h ${DB_HOST} -p 5432 -U ${DB_USER} -d ${DB_NAME} > /mnt/temp/dump.sql
    return $?
}

# Function to try MySQL dump
try_mysql_dump() {
    echo "Attempting MySQL dump..."
    mysqldump -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} > /mnt/temp/dump.sql
    return $?
}

# Try PostgreSQL dump first
try_pg_dump
if [ $? -ne 0 ]; then
    echo "PostgreSQL dump failed. Trying MySQL dump..."
    try_mysql_dump
    if [ $? -ne 0 ]; then
        echo "MySQL dump failed. Exiting."
    fi
fi

# Create backup file using the timestamp
cd /mnt/temp && zip -r /data/${DB_NAME}_${timestamp}.zip * && rm -rf /mnt/temp

echo "Backup completed successfully."
