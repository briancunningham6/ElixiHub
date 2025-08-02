#!/bin/bash

# ElixiPath Deployment Package Creator for ElixiHub

set -e

VERSION="1.0.0"
APP_NAME="elixipath"
PACKAGE_NAME="${APP_NAME}-v${VERSION}.tar.gz"

echo "📦 Creating ElixiHub deployment package..."

# Build the release first
echo "Building release..."
./build.sh

# Create deployment directory structure
echo "Preparing deployment files..."
cd _build/prod/rel/elixipath

# Copy integration files to release
cp ../../../../elixihub.json ./
cp ../../../../roles.json ./
cp ../../../../mcp.json ./

# Copy post-deploy scripts
cp -r ../../../../scripts ./

# Copy deployment documentation
cp ../../../../DEPLOYMENT.md ./

# Create the deployment package
echo "Creating deployment package: ${PACKAGE_NAME}"
cd ..
tar -czf ${PACKAGE_NAME} elixipath/

echo "✅ Deployment package created: _build/prod/rel/${PACKAGE_NAME}"
echo ""
echo "🚀 Deploy to ElixiHub:"
echo "1. Go to your ElixiHub admin: http://your-elixihub/admin/apps"
echo "2. Click 'Deploy New App'"
echo "3. Upload: _build/prod/rel/${PACKAGE_NAME}"
echo "4. Configure deployment settings (see DEPLOYMENT.md)"
echo "5. Deploy!"
echo ""
echo "🔍 After deployment verification:"
echo "- Deployment will automatically run verification script"
echo "- Manual verification: ./scripts/03_verify_deployment.sh"
echo "- Check DEPLOYMENT.md for troubleshooting"
echo ""
echo "📱 User access: http://your-elixihub/apps/elixipath"
echo "🎯 Direct UI: http://your-elixihub:4011/ui/ (requires ElixiHub login)"