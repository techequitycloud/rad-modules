#!/bin/sh

INDEX_FILE="/usr/share/nginx/html/index.html"
SEARCH_DIR="/usr/share/nginx/html"

# Validate that required environment variables are set
if [ -z "$SANITY_STUDIO_PROJECT_ID" ]; then
    echo "ERROR: SANITY_STUDIO_PROJECT_ID environment variable is not set!"
    echo "Please set this variable to your Sanity project ID."
    exit 1
fi

# Set default dataset if not provided
SANITY_STUDIO_DATASET="${SANITY_STUDIO_DATASET:-production}"

echo "Configuring Sanity Studio with projectId: ${SANITY_STUDIO_PROJECT_ID}, dataset: ${SANITY_STUDIO_DATASET}"

# Construct the configuration script
CONFIG_SCRIPT="<script>window.SANITY_CONFIG={projectId:\"${SANITY_STUDIO_PROJECT_ID}\",dataset:\"${SANITY_STUDIO_DATASET}\"};<\/script>"

# 1. Handle index.html injection
if [ -f "$INDEX_FILE" ]; then
    # Try to inject at the marker comment first
    if grep -q "<!-- SANITY_CONFIG_INJECTION_POINT -->" "$INDEX_FILE"; then
        echo "Found injection marker in index.html. Injecting configuration."
        sed -i "s|<!-- SANITY_CONFIG_INJECTION_POINT -->|${CONFIG_SCRIPT}|g" "$INDEX_FILE"
    # Fallback: check for old-style placeholders
    elif grep -q "__PROJECT_ID__" "$INDEX_FILE"; then
        echo "Found placeholders in index.html. Performing substitution."
        sed -i "s|__PROJECT_ID__|${SANITY_STUDIO_PROJECT_ID}|g" "$INDEX_FILE"
        sed -i "s|__DATASET__|${SANITY_STUDIO_DATASET}|g" "$INDEX_FILE"
    # Fallback: inject after <head> tag
    else
        echo "No injection marker found. Injecting after <head> tag."
        sed -i -E "s|(<head[^>]*>)|\\1${CONFIG_SCRIPT}|" "$INDEX_FILE"
    fi
    echo "Configuration injected into index.html successfully."
else
    echo "WARNING: $INDEX_FILE not found. Skipping HTML injection."
fi

# 2. Fallback: Replace hardcoded placeholders in JS bundles
# This handles cases where the application code uses the fallback value directly (e.g., if window.SANITY_CONFIG is missing)
# We search recursively in the web root because Vite/Sanity output structure can vary (e.g. assets vs static)
if [ -d "$SEARCH_DIR" ]; then
    echo "Scanning JavaScript files for hardcoded placeholders..."
    # Use find with -exec to replace in all JS files
    find "$SEARCH_DIR" -type f -name "*.js" -exec grep -l "placeholder-project-id" {} \; | while read -r file; do
        echo "  Replacing placeholder in: $file"
        sed -i "s|placeholder-project-id|${SANITY_STUDIO_PROJECT_ID}|g" "$file"
    done
    echo "JavaScript file scanning complete."
else
    echo "WARNING: $SEARCH_DIR not found. Skipping JS replacement."
fi

echo "Sanity Studio configuration complete. Starting nginx..."
exec "$@"
