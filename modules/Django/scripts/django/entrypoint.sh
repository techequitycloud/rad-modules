#!/bin/bash
set -e

echo "=========================================="
echo "Django Container Startup"
echo "=========================================="

# Display environment info
echo "User: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "Working directory: $(pwd)"
echo "Python version: $(python --version)"

# Verify Django project exists
if [ ! -f "manage.py" ]; then
    echo "ERROR: manage.py not found!"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

if [ ! -d "myproject" ]; then
    echo "ERROR: myproject directory not found!"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

echo "✓ Django project found"

# Check media directory permissions
if [ -d "/app/media" ]; then
    echo "Media directory exists"
    echo "Permissions: $(ls -ld /app/media)"
    # Test write access
    if touch /app/media/.write_test 2>/dev/null; then
        echo "✓ Media directory is writable"
        rm -f /app/media/.write_test
    else
        echo "⚠ WARNING: Media directory is not writable"
    fi
else
    echo "⚠ Media directory not found (will be created by GCS mount)"
fi

# Wait for database (if DB_HOST is set)
if [ -n "$DB_HOST" ]; then
    echo "Waiting for database at $DB_HOST:${DB_PORT:-5432}..."
    
    MAX_RETRIES=30
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Use nc (netcat) instead of psycopg2 for initial check
        if nc -z "$DB_HOST" "${DB_PORT:-5432}" 2>/dev/null; then
            echo "✓ Database port is reachable"
            
            # Now try to connect with Django
            if python manage.py check --database default > /dev/null 2>&1; then
                echo "✓ Database connection verified"
                break
            else
                echo "Database port open but Django can't connect yet..."
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "ERROR: Could not connect to database after $MAX_RETRIES attempts"
        echo "DB_HOST: $DB_HOST"
        echo "DB_PORT: ${DB_PORT:-5432}"
        echo "DB_NAME: $DB_NAME"
        echo "DB_USER: $DB_USER"
        exit 1
    fi
fi

# Run database migrations
echo "Running database migrations..."
if ! python manage.py migrate --noinput; then
    echo "ERROR: Database migrations failed"
    exit 1
fi
echo "✓ Migrations completed"

# Collect static files
echo "Collecting static files..."
if ! python manage.py collectstatic --noinput --clear; then
    echo "ERROR: Static file collection failed"
    exit 1
fi
echo "✓ Static files collected"

# Create superuser if credentials are provided
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Creating superuser..."
    python manage.py shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
        User.objects.create_superuser(
            username='$DJANGO_SUPERUSER_USERNAME',
            email='${DJANGO_SUPERUSER_EMAIL:-admin@example.com}',
            password='$DJANGO_SUPERUSER_PASSWORD'
        )
        print('✓ Superuser created')
    else:
        print('✓ Superuser already exists')
except Exception as e:
    print(f'⚠ Superuser creation failed: {e}')
EOF
fi

echo ""
echo "=========================================="
echo "Starting Gunicorn..."
echo "=========================================="
echo "Bind: 0.0.0.0:8080"
echo "Workers: 2"
echo "Threads: 4"
echo "Timeout: 120s"
echo "=========================================="
echo ""

# ✅ CRITICAL: Use 'exec' to replace shell process with gunicorn
# This ensures the container stays running and PID 1 is gunicorn
exec "$@"
