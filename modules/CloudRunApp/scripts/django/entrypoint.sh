#!/bin/bash
set -e

# Check if manage.py exists
if [ ! -f "manage.py" ]; then
    echo "manage.py not found. Initializing new Django project..."
    # Initialize new project in current directory
    # Note: This will create a default project structure.
    # Settings for WhiteNoise and Secrets configured in the image will be lost
    # unless the user updates the generated settings.py.
    django-admin startproject myproject .
    echo "New Django project initialized."

    # Append STATIC_ROOT to generated settings to allow collectstatic to work
    if [ -f "myproject/settings.py" ]; then
        echo "" >> myproject/settings.py
        echo "# Added by entrypoint.sh for container compatibility" >> myproject/settings.py
        echo "import os" >> myproject/settings.py
        echo "STATIC_ROOT = os.environ.get('STATIC_ROOT', '/app/static')" >> myproject/settings.py
    fi

    # Run migrations for the fresh project (likely SQLite unless configured otherwise)
    echo "Running migrations for new project..."
    python manage.py migrate
else
    echo "Found existing user code."
fi

# Run collectstatic (WhiteNoise)
# This ensures static files are gathered in STATIC_ROOT for WhiteNoise to serve
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Execute the passed command
exec "$@"
