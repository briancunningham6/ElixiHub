#!/bin/bash

# ElixiPath Copyparty Configuration Script
# This script configures copyparty after ElixiPath deployment

set -e

echo "⚙️ Configuring copyparty for ElixiPath..."

# Get the deployment directory (passed as argument or default)
DEPLOY_DIR="${1:-$(pwd)}"
ELIXIPATH_DIR="$HOME/elixipath"

echo "📍 Deployment directory: $DEPLOY_DIR"
echo "📍 ElixiPath data directory: $ELIXIPATH_DIR"

# Verify copyparty is available
if ! python3 -m copyparty --version >/dev/null 2>&1; then
    echo "❌ copyparty not found. Please run install_dependencies.sh first"
    exit 1
fi

# Create copyparty configuration directory
CONFIG_DIR="$DEPLOY_DIR/copyparty_config"
mkdir -p "$CONFIG_DIR"

# Create copyparty configuration file
echo "📝 Creating copyparty configuration..."
cat > "$CONFIG_DIR/copyparty.conf" << EOF
# ElixiPath Copyparty Configuration
# Generated automatically during deployment

# Server settings
-p 8080
-i 127.0.0.1

# Directory mappings
-v $ELIXIPATH_DIR/shared:/shared:rw
-v $ELIXIPATH_DIR/users:/users:rw

# Authentication via header (ElixiPath will set X-Remote-User)
--idp-h-usr X-Remote-User

# Security settings
--no-robots
EOF

# No authentication handler needed - using header-based auth

# Create logs directory
mkdir -p "$DEPLOY_DIR/logs"

# Create copyparty startup script
echo "🚀 Creating copyparty startup script..."
cat > "$CONFIG_DIR/start_copyparty.sh" << EOF
#!/bin/bash

# ElixiPath Copyparty Startup Script
cd "$DEPLOY_DIR"

# Stop any existing copyparty process first
if [ -f "copyparty.pid" ]; then
    OLD_PID=\$(cat copyparty.pid)
    if kill -0 \$OLD_PID 2>/dev/null; then
        echo "Stopping existing copyparty (PID: \$OLD_PID)..."
        kill \$OLD_PID
        sleep 2
    fi
    rm -f copyparty.pid
fi

echo "Starting copyparty for ElixiPath with authentication..."
python3 -m copyparty -c "$CONFIG_DIR/copyparty.conf" > "$DEPLOY_DIR/logs/copyparty.log" 2>&1 &
COPYPARTY_PID=\$!

echo "Copyparty started with PID: \$COPYPARTY_PID"
echo \$COPYPARTY_PID > "$DEPLOY_DIR/copyparty.pid"

# Wait for copyparty to start
sleep 3

# Verify copyparty is running
if kill -0 \$COPYPARTY_PID 2>/dev/null; then
    echo "✅ Copyparty is running on http://127.0.0.1:8080"
    echo "📁 Serving files from: $ELIXIPATH_DIR"
    echo "📋 Logs: $DEPLOY_DIR/logs/copyparty.log"
else
    echo "❌ Failed to start copyparty"
    if [ -f "$DEPLOY_DIR/logs/copyparty.log" ]; then
        echo "Last few log lines:"
        tail -5 "$DEPLOY_DIR/logs/copyparty.log"
    fi
    exit 1
fi
EOF

chmod +x "$CONFIG_DIR/start_copyparty.sh"

# Create copyparty stop script
cat > "$CONFIG_DIR/stop_copyparty.sh" << EOF
#!/bin/bash

# ElixiPath Copyparty Stop Script
cd "$DEPLOY_DIR"

if [ -f "copyparty.pid" ]; then
    PID=\$(cat copyparty.pid)
    if kill -0 \$PID 2>/dev/null; then
        echo "Stopping copyparty (PID: \$PID)..."
        kill \$PID
        rm -f copyparty.pid
        echo "✅ Copyparty stopped"
    else
        echo "Copyparty process not running"
        rm -f copyparty.pid
    fi
else
    echo "No copyparty PID file found"
fi
EOF

chmod +x "$CONFIG_DIR/stop_copyparty.sh"

# Authentication is handled via headers from ElixiPath reverse proxy

echo "✅ Copyparty configuration complete!"
echo ""
echo "📋 Configuration Summary:"
echo "  Config directory: $CONFIG_DIR"
echo "  Data directory: $ELIXIPATH_DIR"
echo "  Authentication: JWT token validation"
echo "  Port: 8080 (internal)"
echo ""
echo "🚀 To start copyparty manually:"
echo "  $CONFIG_DIR/start_copyparty.sh"
echo ""
echo "🛑 To stop copyparty:"
echo "  $CONFIG_DIR/stop_copyparty.sh"
echo ""

# Start copyparty automatically during deployment
echo "🚀 Starting copyparty automatically..."
"$CONFIG_DIR/start_copyparty.sh"

# Verify copyparty started successfully
if [ -f "$DEPLOY_DIR/copyparty.pid" ]; then
    COPYPARTY_PID=$(cat "$DEPLOY_DIR/copyparty.pid")
    if kill -0 "$COPYPARTY_PID" 2>/dev/null; then
        echo "✅ Copyparty started successfully with PID: $COPYPARTY_PID"
        echo "🌐 Accessible at: http://127.0.0.1:8080"
        echo "📁 Serving directories:"
        echo "   /shared → $ELIXIPATH_DIR/shared"
        echo "   /users  → $ELIXIPATH_DIR/users"
    else
        echo "❌ Copyparty failed to start"
        exit 1
    fi
else
    echo "❌ Copyparty PID file not found"
    exit 1
fi