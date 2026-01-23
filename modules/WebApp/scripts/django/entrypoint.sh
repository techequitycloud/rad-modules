#!/bin/bash
set -e

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Migrate database
echo "Migrating database..."
python manage.py migrate

# Create superuser if env vars present
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_EMAIL" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Creating superuser..."
    # We use a script to avoid interactive prompt issues or obscure errors
    python -c "import os; import django; os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings'); django.setup(); from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username=os.environ['DJANGO_SUPERUSER_USERNAME']).exists() or User.objects.create_superuser(os.environ['DJANGO_SUPERUSER_USERNAME'], os.environ['DJANGO_SUPERUSER_EMAIL'], os.environ['DJANGO_SUPERUSER_PASSWORD'])" || echo "Superuser creation failed (maybe already exists)"
fi

# Start Gunicorn
echo "Starting Gunicorn..."
# We bind to 8080 explicitly as per plan
exec gunicorn myproject.wsgi:application --bind 0.0.0.0:8080
