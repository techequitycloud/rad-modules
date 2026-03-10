
import io
import os
from urllib.parse import urlparse

import environ

# Import the original settings from each template
from .basesettings import *

# Load the settings from the environment variable
env = environ.Env()
env.read_env(io.StringIO(os.environ.get("APPLICATION_SETTINGS", None)))

# Setting this value from django-environ
SECRET_KEY = env("SECRET_KEY")

# Ensure myproject is added to the installed applications
if "myproject" not in INSTALLED_APPS:
    INSTALLED_APPS.append("myproject")

if "myproject.sample" not in INSTALLED_APPS:
    INSTALLED_APPS.append("myproject.sample")

# Security Configuration for Cloud Run
# Cloud Run handles SSL termination, so we need to tell Django to trust the headers
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=False)
SESSION_COOKIE_SECURE = env.bool("SESSION_COOKIE_SECURE", default=False)
CSRF_COOKIE_SECURE = env.bool("CSRF_COOKIE_SECURE", default=False)

# Allowed Hosts Configuration
CLOUDRUN_SERVICE_URLS = env("CLOUDRUN_SERVICE_URLS", default=None)
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["*"])

if CLOUDRUN_SERVICE_URLS:
    CSRF_TRUSTED_ORIGINS = env("CLOUDRUN_SERVICE_URLS").split(",")
    # Remove the scheme from URLs for ALLOWED_HOSTS and extend the list
    ALLOWED_HOSTS.extend([urlparse(url).netloc for url in CSRF_TRUSTED_ORIGINS])

# Default false. True allows default landing pages to be visible
DEBUG = env.bool("DEBUG", default=False)

# Set this value from django-environ
DATABASES = {"default": env.db()}

# Change database settings if using the Cloud SQL Auth Proxy
if os.getenv("USE_CLOUD_SQL_AUTH_PROXY", None):
    DATABASES["default"]["HOST"] = "127.0.0.1"
    DATABASES["default"]["PORT"] = 5432

# Static and Media Files Configuration
STATIC_ROOT = env("STATIC_ROOT", default=None)
MEDIA_ROOT = env("MEDIA_ROOT", default=None)
MEDIA_URL = env("MEDIA_URL", default=None)

# Add Whitenoise to Middleware (ensuring it's enabled if not already)
if "whitenoise.middleware.WhiteNoiseMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")

# Define static storage via django-storages[google]
GS_BUCKET_NAME = env("GS_BUCKET_NAME", default=None)

if GS_BUCKET_NAME:
    STATICFILES_DIRS = []
    GS_DEFAULT_ACL = "publicRead"
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.gcloud.GoogleCloudStorage",
        },
        "staticfiles": {
            "BACKEND": "storages.backends.gcloud.GoogleCloudStorage",
        },
    }
else:
    # Use Whitenoise for static files if no GCS bucket is configured
    STORAGES = {
        "default": {
            "BACKEND": "django.core.files.storage.FileSystemStorage",
        },
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
        },
    }
