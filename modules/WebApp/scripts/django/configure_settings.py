import os

with open("myproject/settings.py", "a") as f:
    f.write("""

import os
import environ

env = environ.Env()

# Allow all hosts (Cloud Run handles routing)
ALLOWED_HOSTS = ["*"]

# CSRF Trusted Origins for Cloud Run
CLOUDRUN_SERVICE_URLS = os.environ.get("CLOUDRUN_SERVICE_URLS")
if CLOUDRUN_SERVICE_URLS:
    CSRF_TRUSTED_ORIGINS = CLOUDRUN_SERVICE_URLS.split(",")

# Database
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "django")
DB_USER = os.environ.get("DB_USER", "django")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_PORT = os.environ.get("DB_PORT", "5432")

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': DB_NAME,
        'USER': DB_USER,
        'PASSWORD': DB_PASSWORD,
        'HOST': DB_HOST,
        'PORT': DB_PORT,
    }
}

# Static files
STATIC_ROOT = "/app/static"
MEDIA_ROOT = "/app/media"
STATIC_URL = "/static/"
MEDIA_URL = "/media/"

# Security (Production)
DEBUG = os.environ.get("DEBUG", "False") == "True"
SECRET_KEY = os.environ.get("SECRET_KEY", "django-insecure-default-key-change-me")

""")
