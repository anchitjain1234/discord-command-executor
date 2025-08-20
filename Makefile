# Makefile for Discord Command Executor
# Provides common development tasks and build automation

# Project configuration
PROJECT_NAME := discord-command-executor
BINARY_NAME := bot
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Go configuration
GO_VERSION := $(shell go version | cut -d' ' -f3)
GOPATH := $(shell go env GOPATH)
GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)

# Build configuration
BUILD_DIR := build
SCRIPTS_DIR := scripts
LDFLAGS := -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.gitCommit=$(GIT_COMMIT)

# Production build flags
PROD_LDFLAGS := $(LDFLAGS) -s -w
PROD_BUILD_FLAGS := -trimpath -ldflags "$(PROD_LDFLAGS)"

# Development build flags
DEV_BUILD_FLAGS := -ldflags "$(LDFLAGS)"

# Test configuration
TEST_FLAGS := -race -timeout=30s
COVERAGE_FLAGS := -cover -coverprofile=$(BUILD_DIR)/coverage.out -covermode=atomic

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "Discord Command Executor - Development Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: info
info: ## Show project information
	@echo "$(BLUE)Project Information:$(NC)"
	@echo "  Name: $(PROJECT_NAME)"
	@echo "  Version: $(VERSION)"
	@echo "  Go Version: $(GO_VERSION)"
	@echo "  GOOS/GOARCH: $(GOOS)/$(GOARCH)"
	@echo "  Build Time: $(BUILD_TIME)"
	@echo "  Git Commit: $(GIT_COMMIT)"

# Build targets
.PHONY: build
build: ## Build the application for development
	@echo "$(GREEN)Building $(PROJECT_NAME) for development...$(NC)"
	@$(SCRIPTS_DIR)/build.sh

.PHONY: build-prod
build-prod: clean ## Build the application for production
	@echo "$(GREEN)Building $(PROJECT_NAME) for production...$(NC)"
	@BUILD_ENV=production $(SCRIPTS_DIR)/build.sh

.PHONY: build-all
build-all: ## Build for all supported platforms
	@echo "$(GREEN)Building for all platforms...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@for os in linux darwin windows; do \
		for arch in amd64 arm64; do \
			if [ "$$os" = "windows" ]; then \
				ext=".exe"; \
			else \
				ext=""; \
			fi; \
			echo "Building for $$os/$$arch..."; \
			GOOS=$$os GOARCH=$$arch go build $(PROD_BUILD_FLAGS) \
				-o $(BUILD_DIR)/$(BINARY_NAME)-$$os-$$arch$$ext cmd/bot/main.go; \
		done; \
	done

.PHONY: install
install: build ## Install the binary to $GOPATH/bin
	@echo "$(GREEN)Installing $(BINARY_NAME) to $(GOPATH)/bin...$(NC)"
	@cp $(BUILD_DIR)/$(BINARY_NAME) $(GOPATH)/bin/

# Test targets
.PHONY: test
test: ## Run all tests
	@$(SCRIPTS_DIR)/test.sh

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(GREEN)Running unit tests...$(NC)"
	@go test $(TEST_FLAGS) ./...

.PHONY: test-integration
test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	@INTEGRATION=true $(SCRIPTS_DIR)/test.sh

.PHONY: test-coverage
test-coverage: ## Run tests with coverage
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@go test $(TEST_FLAGS) $(COVERAGE_FLAGS) ./...
	@go tool cover -func=$(BUILD_DIR)/coverage.out
	@go tool cover -html=$(BUILD_DIR)/coverage.out -o $(BUILD_DIR)/coverage.html
	@echo "Coverage report: $(BUILD_DIR)/coverage.html"

.PHONY: test-bench
test-bench: ## Run benchmarks
	@echo "$(GREEN)Running benchmarks...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@go test -bench=. -benchmem ./... | tee $(BUILD_DIR)/benchmarks.txt

# Code quality targets
.PHONY: lint
lint: ## Run code quality checks
	@$(SCRIPTS_DIR)/lint.sh

.PHONY: lint-fix
lint-fix: ## Run code quality checks and auto-fix issues
	@$(SCRIPTS_DIR)/lint.sh --fix

.PHONY: fmt
fmt: ## Format code
	@echo "$(GREEN)Formatting code...$(NC)"
	@gofmt -w .
	@if command -v goimports >/dev/null 2>&1; then \
		goimports -w .; \
	fi

.PHONY: vet
vet: ## Run go vet
	@echo "$(GREEN)Running go vet...$(NC)"
	@go vet ./...

# Development targets
.PHONY: dev
dev: ## Start development environment
	@$(SCRIPTS_DIR)/dev.sh

.PHONY: dev-setup
dev-setup: ## Set up development environment
	@$(SCRIPTS_DIR)/dev.sh --setup

.PHONY: watch
watch: ## Watch for changes and run checks
	@$(SCRIPTS_DIR)/dev.sh --watch

.PHONY: hot-reload
hot-reload: ## Start with hot reload (requires air)
	@$(SCRIPTS_DIR)/dev.sh --hot-reload

# Dependency management
.PHONY: deps
deps: ## Download and verify dependencies
	@echo "$(GREEN)Downloading dependencies...$(NC)"
	@go mod download
	@go mod verify

.PHONY: deps-update
deps-update: ## Update dependencies
	@echo "$(GREEN)Updating dependencies...$(NC)"
	@go get -u ./...
	@go mod tidy

.PHONY: deps-tidy
deps-tidy: ## Tidy dependencies
	@echo "$(GREEN)Tidying dependencies...$(NC)"
	@go mod tidy

# Tool installation
.PHONY: tools
tools: ## Install development tools
	@echo "$(GREEN)Installing development tools...$(NC)"
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/cosmtrek/air@latest
	@go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	@if [ "$(GOOS)" = "darwin" ] && command -v brew >/dev/null 2>&1; then \
		brew install golangci-lint entr; \
	else \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin; \
	fi

# Docker targets
.PHONY: docker-build
docker-build: ## Build Docker image
	@echo "$(GREEN)Building Docker image...$(NC)"
	@docker build -t $(PROJECT_NAME):$(VERSION) .
	@docker tag $(PROJECT_NAME):$(VERSION) $(PROJECT_NAME):latest

.PHONY: docker-run
docker-run: docker-build ## Run in Docker container
	@echo "$(GREEN)Running in Docker container...$(NC)"
	@docker run --rm -it \
		-v $(PWD)/config.yaml:/app/config.yaml:ro \
		$(PROJECT_NAME):$(VERSION)

# Maintenance targets
.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -f $(BINARY_NAME)
	@rm -rf test-results
	@go clean ./...

.PHONY: clean-all
clean-all: clean ## Clean everything including caches
	@echo "$(GREEN)Cleaning all caches...$(NC)"
	@go clean -cache -testcache -modcache

# Git and release targets
.PHONY: tag
tag: ## Create a new git tag (usage: make tag VERSION=v1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)VERSION is required. Usage: make tag VERSION=v1.0.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Creating tag $(VERSION)...$(NC)"
	@git tag -a $(VERSION) -m "Release $(VERSION)"
	@echo "$(YELLOW)Don't forget to push the tag: git push origin $(VERSION)$(NC)"

.PHONY: release
release: clean lint test build-all ## Prepare a release (run all checks and build for all platforms)
	@echo "$(GREEN)Release preparation completed!$(NC)"
	@echo "Built binaries are in $(BUILD_DIR)/"

# Validation targets
.PHONY: validate
validate: deps lint test build ## Run comprehensive validation
	@echo "$(GREEN)Running comprehensive validation...$(NC)"
	@echo "$(GREEN)✓ Dependencies validated$(NC)"
	@echo "$(GREEN)✓ Code quality checked$(NC)"
	@echo "$(GREEN)✓ Tests passed$(NC)"
	@echo "$(GREEN)✓ Build successful$(NC)"

.PHONY: ci
ci: deps lint test build ## Run CI pipeline locally
	@echo "$(GREEN)Running CI pipeline...$(NC)"

# Security targets
.PHONY: security
security: ## Run security checks
	@echo "$(GREEN)Running security checks...$(NC)"
	@if command -v gosec >/dev/null 2>&1; then \
		gosec ./...; \
	else \
		echo "$(YELLOW)gosec not installed. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest$(NC)"; \
	fi

# Default target
.DEFAULT_GOAL := help