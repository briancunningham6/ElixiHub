# Makefile for Hello World App

.PHONY: help build deploy-package clean dev test deps

# Default target
help:
	@echo "Hello World App - Build Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  make build           - Build production release and create deployment tar"
	@echo "  make deploy-package  - Create deployment package (alias for build)"
	@echo "  make dev             - Start development server"
	@echo "  make test            - Run tests"
	@echo "  make deps            - Install dependencies"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make help            - Show this help"

# Build production release and create deployment tar
build:
	@echo "🔨 Building production release..."
	@chmod +x build.sh
	@./build.sh

# Alias for build
deploy-package: build

# Start development server
dev:
	@echo "🚀 Starting development server..."
	@mix phx.server

# Run tests
test:
	@echo "🧪 Running tests..."
	@mix test

# Install dependencies
deps:
	@echo "📦 Installing dependencies..."
	@mix deps.get

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf _build
	@rm -rf deps
	@rm -f hello_world_app*.tar
	@echo "✅ Clean complete"

# Development setup
setup: deps
	@echo "🛠️  Setting up development environment..."
	@mix ecto.setup || echo "Note: No database setup required for this example"
	@mix assets.setup || echo "Note: No assets setup required"
	@echo "✅ Setup complete"
	@echo "Run 'make dev' to start the server"