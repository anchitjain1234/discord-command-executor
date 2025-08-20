#!/bin/bash

# test.sh - Test runner script for Discord Command Executor
# This script runs all tests with proper coverage reporting and validation

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

echo -e "${GREEN}Running Discord Command Executor tests...${NC}"

# Change to project root
cd "$PROJECT_ROOT"

# Parse command line arguments
COVERAGE=${COVERAGE:-true}
VERBOSE=${VERBOSE:-false}
RACE=${RACE:-true}
INTEGRATION=${INTEGRATION:-false}
BENCHMARK=${BENCHMARK:-false}

# Process flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-coverage)
            COVERAGE=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-race)
            RACE=false
            shift
            ;;
        --integration|-i)
            INTEGRATION=true
            shift
            ;;
        --benchmark|-b)
            BENCHMARK=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --no-coverage    Disable coverage reporting"
            echo "  --verbose, -v    Enable verbose output"
            echo "  --no-race        Disable race detection"
            echo "  --integration, -i Run integration tests"
            echo "  --benchmark, -b  Run benchmarks"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure dependencies are up to date
echo -e "${BLUE}Verifying dependencies...${NC}"
go mod download
go mod verify

# Create test results directory
mkdir -p test-results

# Build test flags
TEST_FLAGS="-timeout=30s"
if [[ "$VERBOSE" == "true" ]]; then
    TEST_FLAGS="$TEST_FLAGS -v"
fi

if [[ "$RACE" == "true" ]]; then
    TEST_FLAGS="$TEST_FLAGS -race"
fi

# Coverage setup
COVERAGE_FLAGS=""
if [[ "$COVERAGE" == "true" ]]; then
    COVERAGE_FLAGS="-cover -coverprofile=test-results/coverage.out -covermode=atomic"
fi

# Run unit tests
echo -e "${BLUE}Running unit tests...${NC}"
if ! go test $TEST_FLAGS $COVERAGE_FLAGS ./...; then
    echo -e "${RED}Unit tests failed!${NC}"
    exit 1
fi

# Run integration tests if requested
if [[ "$INTEGRATION" == "true" ]]; then
    echo -e "${BLUE}Running integration tests...${NC}"
    if ! go test $TEST_FLAGS -tags=integration ./...; then
        echo -e "${RED}Integration tests failed!${NC}"
        exit 1
    fi
fi

# Run benchmarks if requested
if [[ "$BENCHMARK" == "true" ]]; then
    echo -e "${BLUE}Running benchmarks...${NC}"
    go test -bench=. -benchmem ./... | tee test-results/benchmarks.txt
fi

# Generate coverage report if coverage is enabled
if [[ "$COVERAGE" == "true" && -f "test-results/coverage.out" ]]; then
    echo -e "${BLUE}Generating coverage report...${NC}"
    
    # Generate HTML coverage report
    go tool cover -html=test-results/coverage.out -o test-results/coverage.html
    
    # Display coverage summary
    COVERAGE_PERCENT=$(go tool cover -func=test-results/coverage.out | tail -n 1 | awk '{print $3}')
    echo -e "${GREEN}Coverage: ${COVERAGE_PERCENT}${NC}"
    
    # Check coverage threshold (configurable)
    COVERAGE_THRESHOLD=${COVERAGE_THRESHOLD:-70}
    COVERAGE_VALUE=$(echo "$COVERAGE_PERCENT" | sed 's/%//')
    
    if (( $(echo "$COVERAGE_VALUE >= $COVERAGE_THRESHOLD" | bc -l) )); then
        echo -e "${GREEN}Coverage meets threshold (>= ${COVERAGE_THRESHOLD}%)${NC}"
    else
        echo -e "${YELLOW}Warning: Coverage below threshold (${COVERAGE_THRESHOLD}%)${NC}"
    fi
fi

# Run go vet
echo -e "${BLUE}Running go vet...${NC}"
if ! go vet ./...; then
    echo -e "${RED}go vet found issues!${NC}"
    exit 1
fi

# Run shadow analysis if go-shadow is available
if command -v shadow &> /dev/null; then
    echo -e "${BLUE}Running shadow analysis...${NC}"
    go vet -vettool=$(which shadow) ./... || echo -e "${YELLOW}Shadow analysis found potential issues${NC}"
fi

echo -e "${GREEN}All tests passed successfully!${NC}"

# Display test results summary
echo -e "${BLUE}Test Results Summary:${NC}"
echo "- Unit tests: ✅"
if [[ "$INTEGRATION" == "true" ]]; then
    echo "- Integration tests: ✅"
fi
if [[ "$BENCHMARK" == "true" ]]; then
    echo "- Benchmarks: ✅ (see test-results/benchmarks.txt)"
fi
if [[ "$COVERAGE" == "true" ]]; then
    echo "- Coverage report: test-results/coverage.html"
fi
echo "- Code quality: ✅"