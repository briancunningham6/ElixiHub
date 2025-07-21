#!/bin/bash

# Task Manager Installation Script

set -e

APP_NAME="task_manager"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME"

echo "Installing Task Manager..."

# Create application directory
sudo mkdir -p $APP_DIR

# Extract files to application directory
echo "Extracting application files to $APP_DIR..."
cd $(dirname $0)
sudo tar -xf task_manager.tar -C /opt/ || {
    echo "Failed to extract application files"
    exit 1
}

# Set proper ownership
sudo chown -R $USER:$USER $APP_DIR
sudo chmod -R 755 $APP_DIR
sudo chmod +x $APP_DIR/install.sh

# Application is already built, just need to set up environment
cd $APP_DIR

# Generate secret key base for production
SECRET_KEY_BASE=$(mix phx.gen.secret || echo "task_manager_secret_key_base_prod_this_must_be_at_least_64_bytes_long_change_in_production")
export SECRET_KEY_BASE

# Set up database URL
DATABASE_URL="ecto://postgres:postgres@localhost/task_manager_prod"
export DATABASE_URL

# Enable Phoenix server
export PHX_SERVER=true

# Verify release binary exists and is executable
if [ ! -f "_build/prod/rel/tasks_app/bin/tasks_app" ]; then
    echo "Error: Release binary not found at _build/prod/rel/tasks_app/bin/tasks_app"
    echo "Available files in _build/prod/rel/:"
    ls -la _build/prod/rel/ || echo "No _build/prod/rel/ directory found"
    exit 1
fi

# Ensure the binary and ERTS binaries are executable
chmod +x "_build/prod/rel/tasks_app/bin/tasks_app"
# Fix permissions for ERTS binaries that may be needed
find "_build/prod/rel/tasks_app/erts-"*/bin -type f -exec chmod +x {} \; 2>/dev/null || true

echo "✓ Release binary verified at _build/prod/rel/tasks_app/bin/tasks_app"

# Create database and run migrations (if possible)
echo "Setting up database..."
./_build/prod/rel/tasks_app/bin/tasks_app eval "TaskManager.Release.migrate()" 2>/dev/null || echo "Database migration skipped (may not be available)"

# Detect OS and create appropriate service
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - create launchd plist
    PLIST_FILE="$HOME/Library/LaunchAgents/com.$APP_NAME.plist"
    
    cat > "$PLIST_FILE" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$APP_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DIR/_build/prod/rel/tasks_app/bin/tasks_app</string>
        <string>start</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MIX_ENV</key>
        <string>prod</string>
        <key>PORT</key>
        <string>4001</string>
        <key>SECRET_KEY_BASE</key>
        <string>$SECRET_KEY_BASE</string>
        <key>DATABASE_URL</key>
        <string>$DATABASE_URL</string>
        <key>PHX_SERVER</key>
        <string>true</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$APP_DIR/task_manager.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_DIR/task_manager.error.log</string>
</dict>
</plist>
PLIST_EOF

    # Load and start the service
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    launchctl start "com.$APP_NAME"
    
    echo "✓ macOS launchd service created and started"
else
    # Linux - create systemd service
    sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Task Manager Application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/_build/prod/rel/tasks_app/bin/tasks_app start
Restart=always
RestartSec=5
Environment=MIX_ENV=prod
Environment=PORT=4001
Environment=SECRET_KEY_BASE=$SECRET_KEY_BASE
Environment=DATABASE_URL=$DATABASE_URL
Environment=PHX_SERVER=true

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    
    echo "✓ Linux systemd service created and started"
fi

echo "Task Manager installed and started successfully!"
echo "Access the application at http://localhost:4001"
