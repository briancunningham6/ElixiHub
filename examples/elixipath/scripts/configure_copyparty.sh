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
--port 8080
--host 127.0.0.1

# Directory mappings
--vol /shared:$ELIXIPATH_DIR/shared:rw
--vol /users:$ELIXIPATH_DIR/users:rw

# Authentication
--auth-cgi $DEPLOY_DIR/scripts/auth_handler.py

# Security settings
--no-robots
--no-thumb
--xff-src 127.0.0.1

# Logging
--log-fk
--access-log $DEPLOY_DIR/logs/copyparty_access.log
--error-log $DEPLOY_DIR/logs/copyparty_errors.log

# Performance
--dotpart
--hardlink
EOF

# Create authentication handler script
echo "🔐 Creating authentication handler..."
cat > "$CONFIG_DIR/auth_handler.py" << 'EOF'
#!/usr/bin/env python3
"""
Copyparty authentication handler for ElixiPath integration.
This script validates JWT tokens from ElixiHub.
"""
import os
import sys
import json
import jwt
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('copyparty_auth.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# JWT configuration (must match ElixiPath)
JWT_SECRET = "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
JWT_ALGORITHM = "HS512"

def authenticate_user():
    """
    Authenticate user based on JWT token from ElixiPath.
    Returns user info if valid, None if invalid.
    """
    try:
        # Get Authorization header
        auth_header = os.environ.get('HTTP_AUTHORIZATION', '')
        
        if not auth_header.startswith('Bearer '):
            logger.warning("Missing or invalid Authorization header")
            return None
            
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        
        # Verify JWT token
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        
        user_info = {
            'username': payload.get('email', 'unknown'),
            'email': payload.get('email'),
            'user_id': payload.get('sub'),
            'roles': payload.get('roles', [])
        }
        
        logger.info(f"Authenticated user: {user_info['email']}")
        return user_info
        
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid JWT token: {e}")
        return None
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        return None

def main():
    """Main authentication handler."""
    user = authenticate_user()
    
    if user:
        # Return user info for copyparty
        response = {
            'username': user['username'],
            'password': 'authenticated',  # Dummy password for copyparty
            'groups': user.get('roles', []),
            'authenticated': True
        }
        print(json.dumps(response))
        sys.exit(0)
    else:
        # Authentication failed
        print(json.dumps({'authenticated': False}))
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# Make auth handler executable
chmod +x "$CONFIG_DIR/auth_handler.py"

# Create logs directory
mkdir -p "$DEPLOY_DIR/logs"

# Create copyparty startup script
echo "🚀 Creating copyparty startup script..."
cat > "$CONFIG_DIR/start_copyparty.sh" << EOF
#!/bin/bash

# ElixiPath Copyparty Startup Script
cd "$DEPLOY_DIR"

echo "Starting copyparty for ElixiPath..."
python3 -m copyparty --config-file "$CONFIG_DIR/copyparty.conf" &
COPYPARTY_PID=\$!

echo "Copyparty started with PID: \$COPYPARTY_PID"
echo \$COPYPARTY_PID > "$DEPLOY_DIR/copyparty.pid"

# Wait for copyparty to start
sleep 2

# Verify copyparty is running
if kill -0 \$COPYPARTY_PID 2>/dev/null; then
    echo "✅ Copyparty is running on http://127.0.0.1:8080"
    echo "📁 Serving files from: $ELIXIPATH_DIR"
else
    echo "❌ Failed to start copyparty"
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

# Install PyJWT for authentication handler
echo "📦 Installing PyJWT for authentication..."
pip3 install PyJWT --user

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