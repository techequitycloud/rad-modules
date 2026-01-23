#!/bin/sh

set -e

echo "==============================================="
echo " Payload CMS Startup"
echo "==============================================="

# Initialize database schema
echo ""
echo "Step 1: Initializing database schema..."
echo "-----------------------------------------------"

if node /app/init-db.mjs; then
  echo ""
  echo "✅ Database schema initialized successfully"
else
  echo ""
  echo "❌ Database initialization failed"
  exit 1
fi

# Start the Next.js server
echo ""
echo "Step 2: Starting Next.js server..."
echo "-----------------------------------------------"
echo ""

exec node server.js
