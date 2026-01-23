#!/bin/sh

INDEX_FILE="/usr/share/nginx/html/index.html"
SEARCH_DIR="/usr/share/nginx/html"

# 1. Handle index.html injection
# Check if the placeholder exists in the file
if grep -q "__PROJECT_ID__" "$INDEX_FILE"; then
    echo "Placeholders found in index.html. Performing substitution."
    sed -i "s|__PROJECT_ID__|${SANITY_STUDIO_PROJECT_ID}|g" "$INDEX_FILE"
    sed -i "s|__DATASET__|${SANITY_STUDIO_DATASET}|g" "$INDEX_FILE"
else
    echo "Placeholders not found in index.html. Injecting configuration script."

    # Construct the script content
    CONFIG_SCRIPT="<script>window.SANITY_CONFIG={projectId:\"${SANITY_STUDIO_PROJECT_ID}\",dataset:\"${SANITY_STUDIO_DATASET}\"};</script>"

    # Inject after <head> tag using extended regex
    sed -i -E "s|(<head[^>]*>)|\\1${CONFIG_SCRIPT}|" "$INDEX_FILE"
fi

# 2. Fallback: Replace hardcoded placeholders in JS bundles
# This handles cases where the application code uses the fallback value directly (e.g., if window.SANITY_CONFIG is missing)
# We search recursively in the web root because Vite/Sanity output structure can vary (e.g. assets vs static)
if [ -d "$SEARCH_DIR" ]; then
    echo "Scanning all files in $SEARCH_DIR for hardcoded placeholders..."
    find "$SEARCH_DIR" -type f -name "*.js" -exec sed -i "s|placeholder-project-id|${SANITY_STUDIO_PROJECT_ID}|g" {} +
else
    echo "Directory $SEARCH_DIR not found. Skipping JS replacement."
fi

echo "Starting Sanity Studio..."
exec "$@"
