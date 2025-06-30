#!/bin/bash

# Build script for Hello World App
# This script creates a production build and packages it as a tar file for deployment

set -e

APP_NAME="hello_world_app"
VERSION=$(grep 'version:' mix.exs | sed 's/.*version: "\(.*\)".*/\1/')
BUILD_DIR="_build/prod"
RELEASE_DIR="${BUILD_DIR}/rel/${APP_NAME}"
TAR_FILE="${APP_NAME}-${VERSION}.tar"

echo "🔨 Building ${APP_NAME} v${VERSION} for production deployment..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf _build/prod
rm -rf deps
rm -f ${APP_NAME}*.tar

# Install dependencies for dev (needed for assets)
echo "📦 Installing dev dependencies for assets..."
mix deps.get

# Install production dependencies
echo "📦 Installing production dependencies..."
MIX_ENV=prod mix deps.get --only prod

# Compile assets
echo "🎨 Compiling assets..."
mix assets.deploy

# Build release
echo "🏗️  Building production release..."
MIX_ENV=prod mix release

# Verify release exists
if [ ! -d "${RELEASE_DIR}" ]; then
    echo "❌ Release build failed - ${RELEASE_DIR} not found"
    exit 1
fi

# Create deployment package
echo "📦 Creating deployment package..."

# Create temporary directory for packaging
TEMP_DIR="tmp_package"
rm -rf ${TEMP_DIR}
mkdir -p ${TEMP_DIR}

# Copy release files
cp -r ${RELEASE_DIR}/* ${TEMP_DIR}/

# Copy configuration files that might be needed
cp -r config ${TEMP_DIR}/
cp mix.exs ${TEMP_DIR}/
cp roles.json ${TEMP_DIR}/

# Create deployment scripts
cat > ${TEMP_DIR}/deploy.sh << 'EOF'
#!/bin/bash
# Deployment script for Hello World App

APP_NAME="hello_world_app"
DEPLOY_PATH=${1:-"/opt/apps/${APP_NAME}"}

echo "Deploying ${APP_NAME} to ${DEPLOY_PATH}..."

# Create app directory
mkdir -p ${DEPLOY_PATH}

# Copy files
cp -r * ${DEPLOY_PATH}/

# Make scripts executable
chmod +x ${DEPLOY_PATH}/bin/*
chmod +x ${DEPLOY_PATH}/deploy.sh

# Create systemd service if it doesn't exist
if [ ! -f "/etc/systemd/system/${APP_NAME}.service" ]; then
    echo "Creating systemd service..."
    sudo tee /etc/systemd/system/${APP_NAME}.service > /dev/null << EOL
[Unit]
Description=${APP_NAME}
After=local-fs.target network.target

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=${DEPLOY_PATH}
ExecStart=${DEPLOY_PATH}/bin/${APP_NAME} start
ExecStop=${DEPLOY_PATH}/bin/${APP_NAME} stop
Restart=on-failure
RestartSec=5
Environment=HOME=${DEPLOY_PATH}
Environment=MIX_ENV=prod
Environment=PHX_SERVER=true
SyslogIdentifier=${APP_NAME}

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable ${APP_NAME}
fi

echo "✅ Deployment complete!"
echo "To start the service: sudo systemctl start ${APP_NAME}"
echo "To check status: sudo systemctl status ${APP_NAME}"
echo "To view logs: journalctl -u ${APP_NAME} -f"
EOF

chmod +x ${TEMP_DIR}/deploy.sh

# Create the tar file
echo "📁 Creating ${TAR_FILE}..."
cd ${TEMP_DIR}
tar -cf ../${TAR_FILE} .
cd ..

# Clean up
rm -rf ${TEMP_DIR}

# Verify tar file
if [ -f "${TAR_FILE}" ]; then
    TAR_SIZE=$(du -h ${TAR_FILE} | cut -f1)
    echo "✅ Build complete!"
    echo "📦 Package: ${TAR_FILE} (${TAR_SIZE})"
    echo "🚀 Ready for deployment to ElixiHub"
    echo ""
    echo "To deploy:"
    echo "1. Go to ElixiHub Admin → Applications → Deploy"
    echo "2. Select your configured host"
    echo "3. Upload ${TAR_FILE}"
    echo "4. Set deployment path (e.g., /opt/apps/${APP_NAME})"
    echo "5. Click Deploy"
else
    echo "❌ Failed to create ${TAR_FILE}"
    exit 1
fi