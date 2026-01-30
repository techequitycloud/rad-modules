#!/bin/bash
set -e

echo "=========================================="
echo "Ghost Container Startup"
echo "=========================================="

# ============================================================================
# Detect Cloud Run Service URL
# ============================================================================

detect_service_url() {
    echo "Attempting to detect Cloud Run service URL..."
    
    # Check if running on Cloud Run
    if [ -z "$K_SERVICE" ]; then
        echo "⚠ Not running on Cloud Run (K_SERVICE not set)"
        return 1
    fi
    
    # Get access token from metadata server
    ACCESS_TOKEN=$(curl -sf --max-time 5 \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
        | jq -r '.access_token // empty' 2>/dev/null)
    
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "⚠ Failed to get access token from metadata server"
        return 1
    fi
    
    # Get Project ID
    PROJECT_ID=$(curl -sf --max-time 5 \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)
    
    if [ -z "$PROJECT_ID" ]; then
        echo "⚠ Failed to get project ID"
        return 1
    fi
    
    # Get Region from Cloud Run environment variable
    REGION="${CLOUD_RUN_REGION:-}"
    
    # Fallback: Try to get region from metadata
    if [ -z "$REGION" ]; then
        REGION=$(curl -sf --max-time 5 \
            -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/region" 2>/dev/null | sed 's|.*/||')
    fi
    
    if [ -z "$REGION" ]; then
        echo "⚠ Failed to determine region"
        return 1
    fi
    
    SERVICE_NAME="$K_SERVICE"
    
    echo "  Project ID: $PROJECT_ID"
    echo "  Region: $REGION"
    echo "  Service Name: $SERVICE_NAME"
    
    # Fetch service details from Cloud Run API v2
    RESPONSE=$(curl -sf --max-time 10 \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://run.googleapis.com/v2/projects/$PROJECT_ID/locations/$REGION/services/$SERVICE_NAME" 2>/dev/null)
    
    if [ -z "$RESPONSE" ]; then
        echo "⚠ Failed to fetch service details from Cloud Run API"
        return 1
    fi
    
    # Extract service URL
    SERVICE_URL=$(echo "$RESPONSE" | jq -r '.uri // empty' 2>/dev/null)
    
    if [ -n "$SERVICE_URL" ]; then
        echo "✓ Detected Service URL: $SERVICE_URL"
        export url="$SERVICE_URL"
        export admin__url="$SERVICE_URL"  # Ghost 6.x admin URL
        return 0
    else
        echo "⚠ Service URL not found in API response"
        return 1
    fi
}

# ============================================================================
# Set Ghost URL
# ============================================================================

# Priority order:
# 1. Explicit 'url' environment variable (highest priority)
# 2. Auto-detected Cloud Run URL
# 3. PORT-based URL (fallback for local testing)

if [ -n "$url" ]; then
    echo "✓ Using explicit URL from environment: $url"
elif detect_service_url; then
    echo "✓ Using auto-detected Cloud Run URL: $url"
else
    # Fallback for local development
    PORT="${PORT:-2368}"
    url="http://localhost:$PORT"
    echo "⚠ Using fallback URL: $url"
fi

# Export for Ghost
export url
export admin__url="${admin__url:-$url}"

# ============================================================================
# Database Configuration Check
# ============================================================================

echo ""
echo "Checking database configuration..."

if [ -z "$database__client" ]; then
    echo "⚠ WARNING: database__client not set. Ghost will use SQLite (not recommended for production)"
fi

# Validate MySQL configuration if specified
if [ "$database__client" = "mysql" ]; then
    echo "MySQL database configuration detected"
    
    # Check if using Unix socket or TCP
    if [ -n "$database__connection__socketPath" ]; then
        echo "  Connection: Unix Socket"
        echo "  Socket Path: $database__connection__socketPath"
        
        # Wait for socket to be available
        SOCKET_PATH="$database__connection__socketPath"
        if [ -e "$SOCKET_PATH" ]; then
            echo "  ✓ Socket exists"
        else
            echo "  ⚠ Socket not found (will be created by Cloud SQL Proxy)"
        fi
    else
        echo "  Connection: TCP"
        echo "  Host: ${database__connection__host}"
        echo "  Port: ${database__connection__port:-3306}"
        
        # Check required variables
        REQUIRED_VARS=(
            "database__connection__host"
            "database__connection__user"
            "database__connection__password"
            "database__connection__database"
        )
        
        MISSING_VARS=()
        for var in "${REQUIRED_VARS[@]}"; do
            if [ -z "${!var}" ]; then
                MISSING_VARS+=("$var")
            fi
        done
        
        if [ ${#MISSING_VARS[@]} -gt 0 ]; then
            echo "ERROR: Missing required MySQL configuration:"
            printf '  - %s\n' "${MISSING_VARS[@]}"
            exit 1
        fi
        
        # Wait for database (only if using TCP)
        if [ -n "$database__connection__host" ] && [ "$database__connection__host" != "127.0.0.1" ]; then
            echo "  Waiting for database at ${database__connection__host}:${database__connection__port:-3306}..."
            
            MAX_RETRIES=30
            RETRY_COUNT=0
            
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                if nc -z "${database__connection__host}" "${database__connection__port:-3306}" 2>/dev/null; then
                    echo "  ✓ Database is reachable"
                    break
                fi
                
                RETRY_COUNT=$((RETRY_COUNT + 1))
                echo "  Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
                sleep 2
            done
            
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                echo "ERROR: Could not connect to database after $MAX_RETRIES attempts"
                exit 1
            fi
        fi
    fi
    
    echo "  ✓ MySQL configuration validated"
fi

# ============================================================================
# Ghost Configuration Summary
# ============================================================================

echo ""
echo "=========================================="
echo "Ghost Configuration"
echo "=========================================="
echo "URL: $url"
echo "Admin URL: ${admin__url:-$url}"
echo "Database: ${database__client:-sqlite3}"
echo "Node Environment: ${NODE_ENV:-production}"
echo "Privacy - Update Check: ${privacy__useUpdateCheck:-true}"
echo "Image Optimization: ${imageOptimization__resize:-true}"
echo "=========================================="
echo ""

# ============================================================================
# Start Ghost
# ============================================================================

echo "Starting Ghost..."
echo ""

# Execute the original Ghost entrypoint
exec docker-entrypoint.sh "$@"
