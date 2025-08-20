#!/bin/bash

# lint.sh - Code quality and linting script for Discord Command Executor
# This script runs comprehensive code quality checks and linting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Running code quality checks for Discord Command Executor...${NC}"

# Change to project root
cd "$PROJECT_ROOT"

# Configuration
FIX=${FIX:-false}
VERBOSE=${VERBOSE:-false}
GOLANGCI_LINT=${GOLANGCI_LINT:-true}
GO_VET=${GO_VET:-true}
GOFMT=${GOFMT:-true}
GOIMPORTS=${GOIMPORTS:-true}
GOMOD=${GOMOD:-true}
SECURITY=${SECURITY:-true}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix|-f)
            FIX=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-golangci-lint)
            GOLANGCI_LINT=false
            shift
            ;;
        --no-vet)
            GO_VET=false
            shift
            ;;
        --no-fmt)
            GOFMT=false
            shift
            ;;
        --no-imports)
            GOIMPORTS=false
            shift
            ;;
        --no-mod)
            GOMOD=false
            shift
            ;;
        --no-security)
            SECURITY=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --fix, -f           Auto-fix issues where possible"
            echo "  --verbose, -v       Enable verbose output"
            echo "  --no-golangci-lint  Skip golangci-lint checks"
            echo "  --no-vet            Skip go vet checks"
            echo "  --no-fmt            Skip gofmt checks"
            echo "  --no-imports        Skip goimports checks"
            echo "  --no-mod            Skip go mod checks"
            echo "  --no-security       Skip security checks"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Track overall success
OVERALL_SUCCESS=true

# Function to run a check and track success
run_check() {
    local name="$1"
    local command="$2"
    
    echo -e "${BLUE}Running $name...${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✓ $name passed${NC}"
    else
        echo -e "${RED}✗ $name failed${NC}"
        OVERALL_SUCCESS=false
    fi
    echo
}

# Go mod verification and tidying
if [[ "$GOMOD" == "true" ]]; then
    echo -e "${BLUE}Checking Go modules...${NC}"
    
    # Verify modules
    if ! go mod verify; then
        echo -e "${RED}Go module verification failed${NC}"
        OVERALL_SUCCESS=false
    fi
    
    # Check if go.mod needs tidying
    go mod tidy
    if [[ -n $(git diff go.mod go.sum 2>/dev/null) ]]; then
        if [[ "$FIX" == "true" ]]; then
            echo -e "${YELLOW}go.mod/go.sum updated with 'go mod tidy'${NC}"
        else
            echo -e "${RED}go.mod/go.sum need tidying. Run 'go mod tidy' or use --fix${NC}"
            OVERALL_SUCCESS=false
        fi
    else
        echo -e "${GREEN}✓ Go modules are clean${NC}"
    fi
    echo
fi

# gofmt checks
if [[ "$GOFMT" == "true" ]]; then
    echo -e "${BLUE}Checking code formatting (gofmt)...${NC}"
    
    # Find unformatted files
    UNFORMATTED=$(gofmt -l . 2>/dev/null || true)
    
    if [[ -n "$UNFORMATTED" ]]; then
        if [[ "$FIX" == "true" ]]; then
            echo "Auto-fixing formatting issues..."
            gofmt -w .
            echo -e "${YELLOW}Code formatting fixed${NC}"
        else
            echo -e "${RED}The following files need formatting:${NC}"
            echo "$UNFORMATTED"
            echo -e "${RED}Run 'gofmt -w .' or use --fix${NC}"
            OVERALL_SUCCESS=false
        fi
    else
        echo -e "${GREEN}✓ Code formatting is correct${NC}"
    fi
    echo
fi

# goimports checks (if available)
if [[ "$GOIMPORTS" == "true" ]] && command -v goimports &> /dev/null; then
    echo -e "${BLUE}Checking import organization (goimports)...${NC}"
    
    # Find files with import issues
    IMPORT_ISSUES=$(goimports -l . 2>/dev/null || true)
    
    if [[ -n "$IMPORT_ISSUES" ]]; then
        if [[ "$FIX" == "true" ]]; then
            echo "Auto-fixing import issues..."
            goimports -w .
            echo -e "${YELLOW}Import organization fixed${NC}"
        else
            echo -e "${RED}The following files have import issues:${NC}"
            echo "$IMPORT_ISSUES"
            echo -e "${RED}Run 'goimports -w .' or use --fix${NC}"
            OVERALL_SUCCESS=false
        fi
    else
        echo -e "${GREEN}✓ Import organization is correct${NC}"
    fi
    echo
elif [[ "$GOIMPORTS" == "true" ]]; then
    echo -e "${YELLOW}goimports not installed, skipping import checks${NC}"
    echo "Install with: go install golang.org/x/tools/cmd/goimports@latest"
    echo
fi

# go vet checks
if [[ "$GO_VET" == "true" ]]; then
    run_check "go vet" "go vet ./..."
fi

# golangci-lint checks
if [[ "$GOLANGCI_LINT" == "true" ]]; then
    if command -v golangci-lint &> /dev/null; then
        GOLANGCI_FLAGS=""
        if [[ "$FIX" == "true" ]]; then
            GOLANGCI_FLAGS="--fix"
        fi
        if [[ "$VERBOSE" == "true" ]]; then
            GOLANGCI_FLAGS="$GOLANGCI_FLAGS --verbose"
        fi
        
        run_check "golangci-lint" "golangci-lint run $GOLANGCI_FLAGS"
    else
        echo -e "${YELLOW}golangci-lint not installed, skipping advanced linting${NC}"
        echo "Install with: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b \$(go env GOPATH)/bin"
        echo
    fi
fi

# Security checks (if gosec is available)
if [[ "$SECURITY" == "true" ]] && command -v gosec &> /dev/null; then
    run_check "gosec security scan" "gosec ./..."
elif [[ "$SECURITY" == "true" ]]; then
    echo -e "${YELLOW}gosec not installed, skipping security checks${NC}"
    echo "Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest"
    echo
fi

# Check for common issues
echo -e "${BLUE}Checking for common issues...${NC}"

# Check for TODO/FIXME comments
TODOS=$(grep -r "TODO\|FIXME\|XXX\|HACK" --include="*.go" . || true)
if [[ -n "$TODOS" ]]; then
    echo -e "${YELLOW}Found TODO/FIXME comments:${NC}"
    echo "$TODOS"
    echo
fi

# Check for fmt.Print* in production code (excluding test files)
DEBUG_PRINTS=$(grep -r "fmt\.Print" --include="*.go" --exclude="*_test.go" . || true)
if [[ -n "$DEBUG_PRINTS" ]]; then
    echo -e "${YELLOW}Found fmt.Print statements in production code:${NC}"
    echo "$DEBUG_PRINTS"
    echo -e "${YELLOW}Consider using proper logging instead${NC}"
    echo
fi

# Check for missing error handling
echo -e "${BLUE}Checking for potential issues...${NC}"

# Look for lines that might be ignoring errors
IGNORED_ERRORS=$(grep -r "_ = " --include="*.go" . | grep -v "_test\.go" || true)
if [[ -n "$IGNORED_ERRORS" ]]; then
    echo -e "${YELLOW}Found potential ignored errors (review manually):${NC}"
    echo "$IGNORED_ERRORS" | head -10
    echo
fi

# Summary
echo -e "${BLUE}Lint Summary:${NC}"
if [[ "$OVERALL_SUCCESS" == "true" ]]; then
    echo -e "${GREEN}✓ All code quality checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some code quality issues found${NC}"
    echo "Run with --fix to auto-fix issues where possible"
    exit 1
fi