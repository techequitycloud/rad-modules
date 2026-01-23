#!/bin/sh

# Replace placeholders with environment variables
sed -i "s|__PROJECT_ID__|${SANITY_STUDIO_PROJECT_ID}|g" /usr/share/nginx/html/index.html
sed -i "s|__DATASET__|${SANITY_STUDIO_DATASET}|g" /usr/share/nginx/html/index.html

echo "Starting Sanity Studio..."
exec "$@"
