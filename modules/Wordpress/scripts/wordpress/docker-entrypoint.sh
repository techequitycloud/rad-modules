#!/usr/bin/env bash
set -Eeuo pipefail

# Cloud Run / Cloud SQL Socket Handling
echo "Searching for Cloud SQL socket..."
SOCKET_FILE=""
MAX_WAIT_SECONDS=30
WAIT_COUNT=0

# Wait for Cloud SQL socket with retry loop
while [ -z "$SOCKET_FILE" ] && [ $WAIT_COUNT -lt $MAX_WAIT_SECONDS ]; do
    if [ -d "/cloudsql" ]; then
        SOCKET_FILE=$(find /cloudsql -type s -print -quit 2>/dev/null)
    fi
    
    if [ -z "$SOCKET_FILE" ] && [ -d "/var/run/mysqld" ]; then
        SOCKET_FILE=$(find /var/run/mysqld -type s -print -quit 2>/dev/null)
    fi
    
    if [ -z "$SOCKET_FILE" ]; then
        if [ $WAIT_COUNT -eq 0 ]; then
            echo "Waiting for Cloud SQL socket..."
        fi
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    fi
done

if [ $WAIT_COUNT -gt 0 ]; then
    echo "Waited ${WAIT_COUNT}s for socket"
fi

if [ -n "$SOCKET_FILE" ]; then
    echo "Found socket: $SOCKET_FILE"
    mkdir -p /tmp
    echo "Symlinking to /tmp/mysqld.sock"
    ln -sf "$SOCKET_FILE" /tmp/mysqld.sock
    # Ensure WORDPRESS_DB_HOST uses the symlinked socket
    export WORDPRESS_DB_HOST="localhost:/tmp/mysqld.sock"
    echo "Set WORDPRESS_DB_HOST to localhost:/tmp/mysqld.sock (socket)"
else
    echo "WARNING: No Cloud SQL socket found after ${MAX_WAIT_SECONDS}s!"
    # Fall back to TCP connection using DB_HOST or DB_IP if available
    if [ -n "${DB_HOST:-}" ]; then
        export WORDPRESS_DB_HOST="$DB_HOST"
        echo "Falling back to TCP: WORDPRESS_DB_HOST=$DB_HOST"
    elif [ -n "${DB_IP:-}" ]; then
        export WORDPRESS_DB_HOST="$DB_IP"
        echo "Falling back to TCP: WORDPRESS_DB_HOST=$DB_IP"
    else
        echo "ERROR: No database connection method available!"
    fi
fi

# Suppress Apache ServerName warning
if [ ! -f /etc/apache2/conf-available/servername.conf ]; then
    echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
    a2enconf servername 2>/dev/null || true
fi

if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ] || { self="$(basename "$0")" && [ "$self" = 'docker-ensure-installed.sh' ]; }; then
	uid="$(id -u)"
	gid="$(id -g)"
	if [ "$uid" = '0' ]; then
		case "$1" in
			apache2*)
				user="${APACHE_RUN_USER:-www-data}"
				group="${APACHE_RUN_GROUP:-www-data}"

				# strip off any '#' symbol ('#1000' is valid syntax for Apache)
				pound='#'
				user="${user#$pound}"
				group="${group#$pound}"
				;;
			*) # php-fpm
				user='www-data'
				group='www-data'
				;;
		esac
	else
		user="$uid"
		group="$gid"
	fi

	if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then
		# if the directory exists and WordPress doesn't appear to be installed AND the permissions of it are root:root, let's chown it (likely a Docker-created directory)
		if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
			chown "$user:$group" .
		fi

		echo >&2 "WordPress not found in $PWD - copying now..."
		if [ -n "$(find -mindepth 1 -maxdepth 1 -not -name wp-content)" ]; then
			echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
		fi
		sourceTarArgs=(
			--create
			--file -
			--directory /usr/src/wordpress
			--owner "$user" --group "$group"
		)
		targetTarArgs=(
			--extract
			--file -
		)
		if [ "$uid" != '0' ]; then
			# avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
			targetTarArgs+=( --no-overwrite-dir )
		fi
		# loop over "pluggable" content in the source, and if it already exists in the destination, skip it
		# https://github.com/docker-library/wordpress/issues/506 ("wp-content" persisted, "akismet" updated, WordPress container restarted/recreated, "akismet" downgraded)
		for contentPath in \
			/usr/src/wordpress/.htaccess \
			/usr/src/wordpress/wp-content/*/*/ \
		; do
			contentPath="${contentPath%/}"
			[ -e "$contentPath" ] || continue
			contentPath="${contentPath#/usr/src/wordpress/}" # "wp-content/plugins/akismet", etc.
			if [ -e "$PWD/$contentPath" ]; then
				echo >&2 "WARNING: '$PWD/$contentPath' exists! (not copying the WordPress version)"
				sourceTarArgs+=( --exclude "./$contentPath" )
			fi
		done
		tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
		echo >&2 "Complete! WordPress has been successfully copied to $PWD"
	fi

	wpEnvs=( "${!WORDPRESS_@}" )
	if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
		for wpConfigDocker in \
			wp-config-docker.php \
			/usr/src/wordpress/wp-config-docker.php \
		; do
			if [ -s "$wpConfigDocker" ]; then
				echo >&2 "No 'wp-config.php' found in $PWD, but 'WORDPRESS_...' variables supplied; copying '$wpConfigDocker' (${wpEnvs[*]})"
				# using "awk" to replace all instances of "put your unique phrase here" with a properly unique string (for AUTH_KEY and friends to have safe defaults if they aren't specified with environment variables)
				awk '
					/put your unique phrase here/ {
						cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
						cmd | getline str
						close(cmd)
						gsub("put your unique phrase here", str)
					}
					/Stop editing/ {
						print "if (getenv(\"WP_REDIS_HOST\")) {"
						print "  define( \"WP_REDIS_HOST\", getenv(\"WP_REDIS_HOST\") );"
						print "}"
					}
					{ print }
				' "$wpConfigDocker" > wp-config.php
				if [ "$uid" = '0' ]; then
					# attempt to ensure that wp-config.php is owned by the run user
					# could be on a filesystem that doesn't allow chown (like some NFS setups)
					chown "$user:$group" wp-config.php || true
				fi
				break
			fi
		done
	fi
fi

exec "$@"
