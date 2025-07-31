#!/bin/bash

# ElixiPath Build Script for ElixiHub Deployment
# Creates a source package for ElixiHub to build on target

set -e

APP_NAME="elixipath"
VERSION=$(grep 'version:' mix.exs | sed 's/.*version: "\(.*\)".*/\1/')
TAR_FILE="${APP_NAME}-${VERSION}.tar"

echo "🔨 Building ${APP_NAME} v${VERSION} for ElixiHub deployment..."

# Clean previous builds
echo "🧹 Cleaning previous packages..."
rm -f ${APP_NAME}*.tar

# Create deployment package (source code for target building)
echo "📦 Creating source deployment package..."

# Create temporary directory for packaging
TEMP_DIR="tmp_package"
rm -rf ${TEMP_DIR}
mkdir -p ${TEMP_DIR}

# Copy source files needed for building on target
echo "📁 Copying source files..."
cp -r lib ${TEMP_DIR}/
cp -r config ${TEMP_DIR}/
cp -r assets ${TEMP_DIR}/
cp -r priv ${TEMP_DIR}/
cp -r rel ${TEMP_DIR}/
cp -r scripts ${TEMP_DIR}/
cp mix.exs ${TEMP_DIR}/
cp mix.lock ${TEMP_DIR}/

# Copy test files if they exist
if [ -d "test" ]; then
    cp -r test ${TEMP_DIR}/
fi

# Copy integration files
cp roles.json ${TEMP_DIR}/
cp mcp.json ${TEMP_DIR}/
cp elixihub.json ${TEMP_DIR}/
cp Dockerfile ${TEMP_DIR}/

# Ensure we don't include any build artifacts
rm -rf ${TEMP_DIR}/_build 2>/dev/null || true
rm -rf ${TEMP_DIR}/deps 2>/dev/null || true

# Create deployment README
cat > ${TEMP_DIR}/DEPLOYMENT.md << 'EOF'
# ElixiPath Deployment

This package contains the source code for ElixiPath - a secure file and media server with MCP capabilities.
The ElixiHub deployment system will automatically:

1. Run pre-deployment script (install Python dependencies)
2. Build the release on the target architecture
3. Install Elixir dependencies and compile assets
4. Run post-deployment script (configure copyparty)
5. Create the systemd service
6. Start the application with copyparty integration

## Features:
- Secure file upload/download with 100MB limits
- Directory organization (shared + user-specific)
- Copyparty web interface integration
- MCP server for AI agent file operations
- ElixiHub SSO integration

## Environment Variables:
- SECRET_KEY_BASE: Auto-generated during deployment
- PHX_HOST: Set to your domain
- PORT: Default port 4011
- ELIXIHUB_JWT_SECRET: For authentication integration

## Dependencies:
- Python 3.8+ with copyparty package (auto-installed during deployment)
- Elixir 1.15+ with Phoenix 1.7+

## Copyparty Installation:
The deployment process will automatically:
1. Check for Python 3.8+
2. Install copyparty via pip3
3. Configure copyparty integration
4. Start copyparty subprocess with authentication

## Port Configuration:
The application will run on port 4011 by default.
- Web UI: http://localhost:4011
- MCP endpoint: http://localhost:4011/mcp
- Copyparty UI: http://localhost:4011/ui

## Deployment Path:
Recommended deployment path: /tmp/elixipath
This ensures proper permissions and avoids home directory issues.
EOF

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
    echo "4. Set deployment path to: /tmp/${APP_NAME}"
    echo "5. Check 'Deploy as Service' (recommended)"
    echo "6. Click Deploy"
else
    echo "❌ Failed to create ${TAR_FILE}"
    exit 1
fi