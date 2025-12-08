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

# If defined, add service URLs to Django security settings
CLOUDRUN_SERVICE_URLS = env("CLOUDRUN_SERVICE_URLS", default=None)
if CLOUDRUN_SERVICE_URLS:
    CSRF_TRUSTED_ORIGINS = env("CLOUDRUN_SERVICE_URLS").split(",")
    # Remove the scheme from URLs for ALLOWED_HOSTS
    ALLOWED_HOSTS = [urlparse(url).netloc for url in CSRF_TRUSTED_ORIGINS]
else:
    ALLOWED_HOSTS = ["*"]

# Default false. True allows default landing pages to be visible
DEBUG = env("DEBUG", default=False)

# Set this value from django-environ
DATABASES = {"default": env.db()}

# Change database settings if using the Cloud SQL Auth Proxy
if os.getenv("USE_CLOUD_SQL_AUTH_PROXY", None):
    DATABASES["default"]["HOST"] = "127.0.0.1"
    DATABASES["default"]["PORT"] = 5432

# Define static storage via django-storages[google]
# FIXED: Read from OS environment first, then fall back to APPLICATION_SETTINGS
GS_BUCKET_NAME = os.environ.get("GS_BUCKET_NAME") or env("GS_BUCKET_NAME", default=None)

if not GS_BUCKET_NAME:
    raise ValueError("GS_BUCKET_NAME environment variable is not set")

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
