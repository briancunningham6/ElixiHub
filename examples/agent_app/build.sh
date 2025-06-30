#!/bin/bash

# Build script for Agent App
# This script creates a production build and packages it as a tar file for deployment

set -e

APP_NAME="agent_app"
VERSION=$(grep 'version:' mix.exs | sed 's/.*version: "\(.*\)".*/\1/')
BUILD_DIR="_build/prod"
RELEASE_DIR="${BUILD_DIR}/rel/${APP_NAME}"
TAR_FILE="${APP_NAME}-${VERSION}.tar"

echo "🔨 Building ${APP_NAME} v${VERSION} for production deployment..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
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
cp mix.exs ${TEMP_DIR}/
cp mix.lock ${TEMP_DIR}/

# Copy any test files that might be needed
if [ -d "test" ]; then
    cp -r test ${TEMP_DIR}/
fi

# Ensure we don't include any build artifacts
rm -rf ${TEMP_DIR}/_build 2>/dev/null || true
rm -rf ${TEMP_DIR}/deps 2>/dev/null || true

# Create roles.json file for the agent app
cat > ${TEMP_DIR}/roles.json << 'EOF'
{
  "roles": [
    {
      "name": "agent:user",
      "description": "Basic agent user - can use chat interface"
    },
    {
      "name": "agent:admin", 
      "description": "Agent administrator - can manage MCP connections"
    }
  ]
}
EOF

# Create a simple README for deployment
cat > ${TEMP_DIR}/DEPLOYMENT.md << 'EOF'
# Agent App Deployment

This package contains the source code for the Agent App.
The ElixiHub deployment system will automatically:

1. Build the release on the target architecture
2. Install dependencies 
3. Compile assets
4. Create the systemd service
5. Start the application

## Environment Variables Required:
- OPENAI_API_KEY: Your OpenAI API key
- ELIXIHUB_JWT_SECRET: JWT secret from ElixiHub
- ELIXIHUB_URL: URL of your ElixiHub instance
- HELLO_WORLD_MCP_URL: URL of hello world MCP endpoint

## Port Configuration:
The application will run on port 4003 by default.
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
    echo "4. Set deployment path (e.g., /opt/apps/${APP_NAME})"
    echo "5. Click Deploy"
    echo ""
    echo "Environment variables needed:"
    echo "- OPENAI_API_KEY: Your OpenAI API key"
    echo "- ELIXIHUB_JWT_SECRET: JWT secret from ElixiHub"
    echo "- ELIXIHUB_URL: URL of your ElixiHub instance"
    echo "- HELLO_WORLD_MCP_URL: URL of hello world MCP endpoint"
else
    echo "❌ Failed to create ${TAR_FILE}"
    exit 1
fi