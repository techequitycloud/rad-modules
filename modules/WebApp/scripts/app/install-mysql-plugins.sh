#!/bin/bash
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

#########################################################################
# Install MySQL Plugins and Components
#########################################################################

set -e

# Required environment variables:
# - MYSQL_PLUGINS: Comma-separated list of plugins to install
# - DB_HOST: Database host
# - DB_PORT: Database port
# - DB_NAME: Database name
# - ROOT_USER: Database root username (typically 'root')
# - ROOT_PASSWORD: Database root password

echo "=== MySQL Plugins Installation Job ==="
echo "Plugins to install: ${MYSQL_PLUGINS}"
echo "Database: ${DB_NAME}"

# Install MySQL client
echo "Installing MySQL client..."
apt-get update -qq && apt-get install -y -qq default-mysql-client

# Parse comma-separated plugins list
IFS=',' read -ra PLUGINS <<< "$MYSQL_PLUGINS"

# Install each plugin
for plugin in "${PLUGINS[@]}"; do
    # Trim whitespace
    plugin=$(echo "$plugin" | xargs)

    if [ -z "$plugin" ]; then
        continue
    fi

    echo "Installing plugin: ${plugin}..."

    # Use root user to install plugins
    # Different syntax for different plugin types
    case "$plugin" in
        # Validate Password Component (MySQL 8.0+)
        validate_password|component_validate_password)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL COMPONENT 'file://component_validate_password';
EOSQL
            ;;

        # Audit Log Plugin
        audit_log)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN audit_log SONAME 'audit_log.so';
EOSQL
            ;;

        # Authentication Plugins
        authentication_ldap_simple|authentication_ldap_sasl)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN ${plugin} SONAME '${plugin}.so';
EOSQL
            ;;

        # Clone Plugin (MySQL 8.0+)
        clone)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN ${plugin} SONAME 'mysql_clone.so';
EOSQL
            ;;

        # Group Replication
        group_replication)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN ${plugin} SONAME 'group_replication.so';
EOSQL
            ;;

        # Semisync Replication
        rpl_semi_sync_master|rpl_semi_sync_slave|rpl_semi_sync_source|rpl_semi_sync_replica)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN ${plugin} SONAME 'semisync_master.so';
EOSQL
            ;;

        # Generic plugin installation
        *)
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
                INSTALL PLUGIN ${plugin} SONAME '${plugin}.so';
EOSQL
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "✓ Plugin ${plugin} installed successfully"
    else
        echo "⚠ Warning: Failed to install plugin ${plugin}"
        # Continue with other plugins even if one fails
    fi
done

# Verify installed plugins
echo ""
echo "Installed plugins in database ${DB_NAME}:"
mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${ROOT_USER}" -p"${ROOT_PASSWORD}" <<-EOSQL
    SELECT PLUGIN_NAME, PLUGIN_STATUS, PLUGIN_TYPE, PLUGIN_LIBRARY
    FROM INFORMATION_SCHEMA.PLUGINS
    WHERE PLUGIN_LIBRARY IS NOT NULL
    ORDER BY PLUGIN_NAME;
EOSQL

echo ""
echo "=== MySQL Plugins Installation Complete ==="
