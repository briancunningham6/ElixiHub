#!/bin/bash

# Test script for Agent App deployment
# This script helps verify that the deployment is working correctly

set -e

APP_NAME="agent_app"
DEFAULT_PORT=4003
HOST="localhost"

echo "🧪 Testing Agent App deployment..."

# Get port from environment or use default
PORT=${PORT:-$DEFAULT_PORT}
BASE_URL="http://${HOST}:${PORT}"

echo "📍 Testing app at: ${BASE_URL}"

# Function to check if service is running
check_service() {
    echo "🔍 Checking if service is running..."
    
    # Check if port is open
    if nc -z ${HOST} ${PORT} 2>/dev/null; then
        echo "✅ Port ${PORT} is open"
        return 0
    else
        echo "❌ Port ${PORT} is not accessible"
        return 1
    fi
}

# Function to test health endpoint
test_health() {
    echo "🏥 Testing health endpoint..."
    
    if curl -s -f "${BASE_URL}/health" > /dev/null; then
        echo "✅ Health endpoint responding"
        return 0
    else
        echo "❌ Health endpoint not responding"
        return 1
    fi
}

# Function to test main page
test_main_page() {
    echo "🏠 Testing main page..."
    
    if curl -s -f "${BASE_URL}/" > /dev/null; then
        echo "✅ Main page accessible"
        return 0
    else
        echo "❌ Main page not accessible"
        return 1
    fi
}

# Function to test MCP endpoint
test_mcp_endpoint() {
    echo "🔌 Testing MCP endpoint..."
    
    # Test with a simple MCP request
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/mcp" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}')
    
    if [ "$response" = "200" ] || [ "$response" = "401" ]; then
        echo "✅ MCP endpoint responding (HTTP $response)"
        return 0
    else
        echo "❌ MCP endpoint not responding properly (HTTP $response)"
        return 1
    fi
}

# Function to check logs
check_logs() {
    echo "📜 Checking application logs..."
    
    if [ -f "/tmp/${APP_NAME}.log" ]; then
        echo "📄 Log file found at /tmp/${APP_NAME}.log"
        echo "📝 Last 10 lines:"
        tail -10 "/tmp/${APP_NAME}.log"
    elif [ -f "${APP_NAME}.log" ]; then
        echo "📄 Log file found at ${APP_NAME}.log"
        echo "📝 Last 10 lines:"
        tail -10 "${APP_NAME}.log"
    else
        echo "⚠️  No log file found"
    fi
}

# Main test sequence
echo "🚀 Starting deployment tests..."
echo ""

# Wait a moment for the service to be ready
echo "⏳ Waiting 5 seconds for service to be ready..."
sleep 5

TESTS_PASSED=0
TESTS_TOTAL=4

# Run tests
if check_service; then
    ((TESTS_PASSED++))
fi

if test_health; then
    ((TESTS_PASSED++))
fi

if test_main_page; then
    ((TESTS_PASSED++))
fi

if test_mcp_endpoint; then
    ((TESTS_PASSED++))
fi

echo ""
echo "📊 Test Results: ${TESTS_PASSED}/${TESTS_TOTAL} tests passed"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo "🎉 All tests passed! Agent App is deployed and running correctly."
    echo ""
    echo "🌐 Application URLs:"
    echo "   • Main page: ${BASE_URL}/"
    echo "   • Health check: ${BASE_URL}/health"
    echo "   • Chat interface: ${BASE_URL}/chat"
    echo "   • MCP endpoint: ${BASE_URL}/api/mcp"
    if [ "${HOST}" = "localhost" ]; then
        echo "   • Live Dashboard (dev): ${BASE_URL}/dev/dashboard"
    fi
    exit 0
else
    echo "❌ Some tests failed. Check the logs for more information."
    check_logs
    exit 1
fi