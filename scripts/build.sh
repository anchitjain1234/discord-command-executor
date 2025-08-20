#!/bin/bash

# build.sh - Build script for Discord Command Executor
# This script builds the Go application with proper optimization and versioning

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Building Discord Command Executor...${NC}"

# Change to project root
cd "$PROJECT_ROOT"

# Set build variables
VERSION=${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo "dev")}
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo "unknown")}

# Build flags
BUILD_FLAGS="-v"
LDFLAGS="-X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}"

# Production build optimization flags
if [[ "${BUILD_ENV:-dev}" == "production" ]]; then
    echo -e "${YELLOW}Building for production...${NC}"
    BUILD_FLAGS="${BUILD_FLAGS} -trimpath"
    LDFLAGS="${LDFLAGS} -s -w"  # Strip debug info
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -f bot
rm -rf build/

# Create build directory
mkdir -p build

# Build the main application
echo "Building main application..."
go build ${BUILD_FLAGS} -ldflags "${LDFLAGS}" -o build/bot cmd/bot/main.go

# Build all packages to verify they compile
echo "Building all packages..."
go build ./...

# Create a simple wrapper script
cat > build/run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec ./bot "$@"
EOF
chmod +x build/run.sh

# Verify the build
if [[ -f "build/bot" ]]; then
    echo -e "${GREEN}Build successful!${NC}"
    echo "Executable: build/bot"
    echo "Version: ${VERSION}"
    echo "Build time: ${BUILD_TIME}"
    
    # Display binary info
    file build/bot
    ls -lh build/bot
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi