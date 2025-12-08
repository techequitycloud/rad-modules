
FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . /app/

# Port is handled by Cloud Run, but good to document
EXPOSE 8080

# The command is handled by the Procfile via buildpacks, but if we run this container directly
# we should default to gunicorn. We wrap it to construct DATABASE_URL.
CMD ["/bin/bash", "-c", "export DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@$DB_HOST/$DB_NAME && gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 --timeout 0 myproject.wsgi:application"]
