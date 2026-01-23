FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
RUN pip install django gunicorn psycopg2-binary django-environ google-cloud-storage

# Create Django Project
RUN django-admin startproject myproject .

# Configure Settings
COPY configure_settings.py /app/
RUN python configure_settings.py

# Overwrite URLs
COPY urls.py /app/myproject/urls.py

# Create directories for static/media
RUN mkdir -p /app/static /app/media

# Create entrypoint
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Create non-root user and switch
RUN groupadd -g 1000 django && \
    useradd -u 1000 -g django -s /bin/bash -m django && \
    chown -R django:django /app

USER django

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/entrypoint.sh"]
