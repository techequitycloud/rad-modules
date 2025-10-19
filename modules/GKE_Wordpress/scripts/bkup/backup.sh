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

# Get the current timestamp
timestamp=$(date +%Y%m%d%H%M%S)

# Create temp directory
mkdir -p /mnt/temp

# Perform the database dump (password inline - less secure)
mysqldump -h ${DB_HOST} -P 3306 -u ${DB_USER} -p${DB_PASSWORD} --single-transaction --routines --triggers ${DB_NAME} > /mnt/temp/dump.sql || { echo "mysqldump failed"; exit 1; }

# Create backup file using the timestamp
cd /mnt/temp && zip -r /data/${DB_NAME}_${timestamp}.zip * && rm -rf /mnt/temp

