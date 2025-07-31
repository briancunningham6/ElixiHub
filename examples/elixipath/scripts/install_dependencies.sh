#!/bin/bash

# ElixiPath Dependencies Installation Script
# This script is run during ElixiHub deployment to install required dependencies

set -e

echo "🔧 Installing ElixiPath dependencies..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get Python version
get_python_version() {
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0"
}

# Check for Python 3.8+
echo "📋 Checking Python version..."
if command_exists python3; then
    PYTHON_VERSION=$(get_python_version)
    echo "Found Python $PYTHON_VERSION"
    
    # Check if version is 3.8 or higher
    if [ "$(echo "$PYTHON_VERSION >= 3.8" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        echo "✅ Python version is sufficient"
    else
        echo "❌ Python 3.8+ required, found $PYTHON_VERSION"
        echo "Please install Python 3.8 or higher"
        exit 1
    fi
else
    echo "❌ Python 3 not found"
    echo "Please install Python 3.8+"
    exit 1
fi

# Check for pip3
echo "📋 Checking pip3..."
if command_exists pip3; then
    echo "✅ pip3 found"
else
    echo "❌ pip3 not found"
    echo "Please install pip3"
    exit 1
fi

# Install copyparty
echo "📦 Installing copyparty..."
if pip3 show copyparty >/dev/null 2>&1; then
    echo "📦 copyparty already installed, checking version..."
    CURRENT_VERSION=$(pip3 show copyparty | grep Version | cut -d' ' -f2)
    echo "Current version: $CURRENT_VERSION"
    
    echo "🔄 Upgrading copyparty to latest version..."
    pip3 install --upgrade copyparty --user
else
    echo "📦 Installing copyparty..."
    pip3 install copyparty --user
fi

# Verify installation
echo "🔍 Verifying copyparty installation..."
if python3 -m copyparty --version >/dev/null 2>&1; then
    VERSION=$(python3 -m copyparty --version 2>&1 | head -n1)
    echo "✅ copyparty installed successfully: $VERSION"
else
    echo "❌ copyparty installation failed"
    exit 1
fi

# Create directories
echo "📁 Creating ElixiPath directories..."
ELIXIPATH_DIR="$HOME/elixipath"
mkdir -p "$ELIXIPATH_DIR/shared"
mkdir -p "$ELIXIPATH_DIR/users"
echo "✅ Created directories at $ELIXIPATH_DIR"

# Set permissions
echo "🔒 Setting directory permissions..."
chmod 755 "$ELIXIPATH_DIR"
chmod 755 "$ELIXIPATH_DIR/shared"
chmod 755 "$ELIXIPATH_DIR/users"

echo "✅ ElixiPath dependencies installed successfully!"
echo ""
echo "📋 Installation Summary:"
echo "  Python: $PYTHON_VERSION"
echo "  copyparty: $(python3 -m copyparty --version 2>&1 | head -n1)"
echo "  Directory: $ELIXIPATH_DIR"
echo ""
echo "🚀 ElixiPath is ready to deploy!"