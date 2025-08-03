#!/bin/bash
# Script to manually trigger analytics cleanup

# Load environment variables
source .env 2>/dev/null || true

# Get the environment (default to production)
ENV=${1:-production}

# Set the API URL based on environment
if [ "$ENV" = "development" ]; then
    API_URL="http://localhost:8787"
else
    API_URL="https://api.openvine.co"
fi

# Set the auth token
AUTH_TOKEN=${CLEANUP_AUTH_TOKEN:-"your-secure-cleanup-token"}

echo "Triggering analytics cleanup on $ENV environment..."
echo "URL: $API_URL/analytics/cleanup"

# Make the cleanup request
response=$(curl -X POST "$API_URL/analytics/cleanup" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -s -w "\nHTTP_STATUS:%{http_code}")

# Extract HTTP status
http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_STATUS:/d')

# Check response
if [ "$http_status" = "200" ]; then
    echo "✅ Cleanup successful!"
    echo "Response: $body"
else
    echo "❌ Cleanup failed with status $http_status"
    echo "Response: $body"
    exit 1
fi