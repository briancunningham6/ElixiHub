#!/bin/bash

# ElixiPath Deployment Verification Script
# This script verifies that ElixiPath and copyparty are working correctly

set -e

echo "🔍 Verifying ElixiPath deployment..."

DEPLOY_DIR="${1:-$(pwd)}"
ELIXIPATH_PORT="${ELIXIPATH_PORT:-4011}"
COPYPARTY_PORT="8080"

echo "📍 Deployment directory: $DEPLOY_DIR"

# Check if ElixiPath is running
echo "🌐 Checking ElixiPath server on port $ELIXIPATH_PORT..."
if curl -s "http://localhost:$ELIXIPATH_PORT/" >/dev/null; then
    echo "✅ ElixiPath server is responding"
else
    echo "❌ ElixiPath server is not responding on port $ELIXIPATH_PORT"
    exit 1
fi

# Check if copyparty is running
echo "📁 Checking copyparty server on port $COPYPARTY_PORT..."
if curl -s "http://localhost:$COPYPARTY_PORT/" >/dev/null; then
    echo "✅ Copyparty server is responding"
else
    echo "❌ Copyparty server is not responding on port $COPYPARTY_PORT"
    echo "📋 Checking copyparty logs..."
    if [ -f "$DEPLOY_DIR/logs/copyparty.log" ]; then
        echo "Last 10 lines from copyparty.log:"
        tail -10 "$DEPLOY_DIR/logs/copyparty.log"
    else
        echo "No copyparty.log found"
    fi
    exit 1
fi

# Test copyparty authentication header
echo "🔐 Testing copyparty authentication..."
RESPONSE=$(curl -s -H "X-Remote-User: test@example.com" "http://localhost:$COPYPARTY_PORT/" || echo "ERROR")
if echo "$RESPONSE" | grep -q "welcome back test@example.com"; then
    echo "✅ Copyparty authentication working correctly"
elif echo "$RESPONSE" | grep -q "ERROR"; then
    echo "❌ Failed to connect to copyparty"
    exit 1
else
    echo "⚠️  Copyparty responding but authentication may not be working"
    echo "Response preview: $(echo "$RESPONSE" | head -1)"
fi

# Check if directories exist
ELIXIPATH_DIR="$HOME/elixipath"
echo "📁 Checking ElixiPath directories..."
if [ -d "$ELIXIPATH_DIR" ]; then
    echo "✅ ElixiPath directory exists: $ELIXIPATH_DIR"
else
    echo "❌ ElixiPath directory missing: $ELIXIPATH_DIR"
    exit 1
fi

# Check log files
echo "📋 Checking log files..."
if [ -f "$DEPLOY_DIR/logs/copyparty.log" ]; then
    LOG_SIZE=$(wc -l < "$DEPLOY_DIR/logs/copyparty.log")
    echo "✅ Copyparty log exists ($LOG_SIZE lines)"
else
    echo "⚠️  Copyparty log not found"
fi

# Check PID files
echo "🔧 Checking process management..."
if [ -f "$DEPLOY_DIR/copyparty.pid" ]; then
    COPYPARTY_PID=$(cat "$DEPLOY_DIR/copyparty.pid")
    if kill -0 "$COPYPARTY_PID" 2>/dev/null; then
        echo "✅ Copyparty process running (PID: $COPYPARTY_PID)"
    else
        echo "❌ Copyparty PID file exists but process not running"
        rm -f "$DEPLOY_DIR/copyparty.pid"
        exit 1
    fi
else
    echo "⚠️  Copyparty PID file not found"
fi

echo ""
echo "🎉 ElixiPath deployment verification complete!"
echo ""
echo "📋 Deployment Summary:"
echo "  ElixiPath: http://localhost:$ELIXIPATH_PORT"
echo "  Copyparty: http://localhost:$COPYPARTY_PORT"
echo "  Data directory: $ELIXIPATH_DIR"
echo "  Authentication: JWT + Header-based"
echo ""
echo "🚀 Next steps:"
echo "  1. Configure ElixiHub SSO integration"
echo "  2. Test file upload/download through ElixiPath UI"
echo "  3. Verify MCP server endpoints"
echo ""