#!/bin/bash

# dev.sh - Development workflow script for Discord Command Executor
# This script provides a comprehensive development environment with hot reload and monitoring

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Discord Command Executor Development Environment${NC}"

# Change to project root
cd "$PROJECT_ROOT"

# Default configuration
WATCH=${WATCH:-true}
LINT=${LINT:-true}
TEST=${TEST:-true}
HOT_RELOAD=${HOT_RELOAD:-false}
CONFIG_FILE=${CONFIG_FILE:-"config.yaml"}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch|-w)
            WATCH=true
            shift
            ;;
        --no-watch)
            WATCH=false
            shift
            ;;
        --lint|-l)
            LINT=true
            shift
            ;;
        --no-lint)
            LINT=false
            shift
            ;;
        --test|-t)
            TEST=true
            shift
            ;;
        --no-test)
            TEST=false
            shift
            ;;
        --hot-reload|-r)
            HOT_RELOAD=true
            shift
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --setup)
            setup_dev_env
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

show_help() {
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Commands:"
    echo "  setup     Set up development environment"
    echo ""
    echo "Options:"
    echo "  --watch, -w       Enable file watching (default: true)"
    echo "  --no-watch        Disable file watching"
    echo "  --lint, -l        Enable linting on changes (default: true)"
    echo "  --no-lint         Disable linting"
    echo "  --test, -t        Enable testing on changes (default: true)"
    echo "  --no-test         Disable testing"
    echo "  --hot-reload, -r  Enable hot reload (experimental)"
    echo "  --config, -c FILE Specify config file (default: config.yaml)"
    echo "  --help, -h        Show this help message"
}

setup_dev_env() {
    echo -e "${BLUE}Setting up development environment...${NC}"
    
    # Install development tools
    echo "Installing development tools..."
    
    # Check if golangci-lint is installed
    if ! command -v golangci-lint &> /dev/null; then
        echo "Installing golangci-lint..."
        if command -v brew &> /dev/null; then
            brew install golangci-lint
        else
            curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
        fi
    fi
    
    # Check if air is installed (for hot reload)
    if ! command -v air &> /dev/null; then
        echo "Installing air for hot reload..."
        go install github.com/cosmtrek/air@latest
    fi
    
    # Check if entr is available (alternative file watcher)
    if ! command -v entr &> /dev/null && [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing entr for file watching..."
        if command -v brew &> /dev/null; then
            brew install entr
        fi
    fi
    
    # Create sample config if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Creating sample configuration file..."
        create_sample_config
    fi
    
    echo -e "${GREEN}Development environment setup complete!${NC}"
}

create_sample_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Sample configuration for Discord Command Executor
discord:
  token: "your-bot-token-here"
  guild_id: "your-guild-id-here"

executor:
  max_concurrent: 5
  timeout: 30s
  memory_limit: "128MB"
  cpu_limit: 0.5
  docker_image: "alpine:latest"

logging:
  level: "debug"
  format: "json"

server:
  port: 8080
  host: "localhost"
EOF
    echo -e "${YELLOW}Created sample config file: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Please update the configuration with your Discord bot token and guild ID.${NC}"
}

# Function to run development checks
run_dev_checks() {
    local changed_files="$1"
    
    if [[ "$LINT" == "true" ]]; then
        echo -e "${BLUE}Running linter...${NC}"
        if command -v golangci-lint &> /dev/null; then
            golangci-lint run --fast
        else
            go vet ./...
        fi
    fi
    
    if [[ "$TEST" == "true" ]]; then
        echo -e "${BLUE}Running tests...${NC}"
        go test -short ./...
    fi
}

# Function for file watching
watch_files() {
    echo -e "${CYAN}Watching for file changes...${NC}"
    echo "Press Ctrl+C to stop"
    
    if command -v entr &> /dev/null; then
        # Use entr if available (more reliable)
        find . -name "*.go" -not -path "./vendor/*" -not -path "./.git/*" | entr -r sh -c '
            echo "Files changed, running checks..."
            ./scripts/dev.sh --no-watch
        '
    elif command -v fswatch &> /dev/null; then
        # Use fswatch on macOS
        fswatch -r --event Created --event Updated --event Renamed \
            --exclude="\\.git" --exclude="vendor" --exclude="build" \
            --include="\\.go$" . | while read -r changed_file; do
            echo -e "${YELLOW}File changed: $changed_file${NC}"
            run_dev_checks "$changed_file"
        done
    else
        echo -e "${YELLOW}No file watcher available. Install 'entr' or 'fswatch' for file watching.${NC}"
        echo "Running checks once..."
        run_dev_checks ""
    fi
}

# Function for hot reload
hot_reload() {
    if command -v air &> /dev/null; then
        echo -e "${CYAN}Starting hot reload with air...${NC}"
        air
    else
        echo -e "${YELLOW}Air not installed. Install with: go install github.com/cosmtrek/air@latest${NC}"
        echo "Falling back to file watching..."
        watch_files
    fi
}

# Main execution
echo -e "${BLUE}Preparing development environment...${NC}"

# Ensure dependencies are up to date
echo "Updating dependencies..."
go mod download
go mod tidy

# Run initial checks
echo -e "${BLUE}Running initial checks...${NC}"
run_dev_checks ""

# Check configuration
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}Using config file: $CONFIG_FILE${NC}"
else
    echo -e "${YELLOW}Config file not found: $CONFIG_FILE${NC}"
    echo "Run './scripts/dev.sh --setup' to create a sample config"
fi

# Start appropriate mode
if [[ "$HOT_RELOAD" == "true" ]]; then
    hot_reload
elif [[ "$WATCH" == "true" ]]; then
    watch_files
else
    echo -e "${GREEN}Development checks completed!${NC}"
    echo "Use --watch to enable continuous monitoring"
fi