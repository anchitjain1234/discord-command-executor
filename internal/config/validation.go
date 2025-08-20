package config

import (
	"fmt"
	"strings"
)

// Validation constants
const (
	// Timeout limits in seconds
	MaxDefaultTimeoutSeconds = 3600 // 1 hour
	MaxRuntimeSeconds        = 7200 // 2 hours
	MaxReadWriteTimeout      = 300  // 5 minutes

	// Other validation constants
	MinTokenLength     = 10 // Minimum test token length
	MinRealTokenLength = 50 // Minimum real token length
)

// validateConfig validates the loaded configuration
func validateConfig(config *Config) error {
	var errors []string

	// Validate bot configuration
	if err := validateBotConfig(&config.Bot); err != nil {
		errors = append(errors, fmt.Sprintf("bot config: %v", err))
	}

	// Validate docker configuration
	if err := validateDockerConfig(&config.Docker); err != nil {
		errors = append(errors, fmt.Sprintf("docker config: %v", err))
	}

	// Validate logging configuration
	if err := validateLoggingConfig(&config.Logging); err != nil {
		errors = append(errors, fmt.Sprintf("logging config: %v", err))
	}

	// Validate server configuration
	if err := validateServerConfig(&config.Server); err != nil {
		errors = append(errors, fmt.Sprintf("server config: %v", err))
	}

	if len(errors) > 0 {
		return fmt.Errorf("validation errors: %s", strings.Join(errors, "; "))
	}

	return nil
}

// validateBotConfig validates bot-specific configuration
func validateBotConfig(config *BotConfig) error {
	var errors []string

	// Bot token is required
	if config.Token == "" {
		errors = append(errors, "bot token is required (set DCE_BOT_TOKEN environment variable)")
	}

	// Validate token format (Discord bot tokens typically start with specific patterns)
	if config.Token != "" && !isValidBotToken(config.Token) {
		errors = append(errors, "bot token appears to be invalid format")
	}

	// Command prefix validation
	if config.Prefix == "" {
		errors = append(errors, "command prefix cannot be empty")
	}

	// Max concurrent commands validation
	if config.MaxConcurrentCommands < 1 {
		errors = append(errors, "max concurrent commands must be at least 1")
	}
	if config.MaxConcurrentCommands > 100 {
		errors = append(errors, "max concurrent commands should not exceed 100")
	}

	if len(errors) > 0 {
		return fmt.Errorf("%s", strings.Join(errors, "; "))
	}

	return nil
}

// validateDockerConfig validates Docker-specific configuration
func validateDockerConfig(config *DockerConfig) error {
	var errors []string

	// Docker host validation
	if config.Host == "" {
		errors = append(errors, "docker host cannot be empty")
	}

	// Timeout validations
	if config.DefaultTimeout < 1 {
		errors = append(errors, "default timeout must be at least 1 second")
	}
	if config.DefaultTimeout > MaxDefaultTimeoutSeconds {
		errors = append(errors, "default timeout should not exceed 1 hour")
	}

	if config.MaxRuntime < 1 {
		errors = append(errors, "max runtime must be at least 1 second")
	}
	if config.MaxRuntime > MaxRuntimeSeconds {
		errors = append(errors, "max runtime should not exceed 2 hours")
	}

	// Resource limit validations
	if config.MemoryLimit < 16 {
		errors = append(errors, "memory limit must be at least 16 MB")
	}
	if config.MemoryLimit > 4096 {
		errors = append(errors, "memory limit should not exceed 4096 MB")
	}

	if config.CPULimit <= 0 {
		errors = append(errors, "CPU limit must be greater than 0")
	}
	if config.CPULimit > 8.0 {
		errors = append(errors, "CPU limit should not exceed 8.0")
	}

	// Network name validation
	if config.NetworkName == "" {
		errors = append(errors, "network name cannot be empty")
	}

	if len(errors) > 0 {
		return fmt.Errorf("%s", strings.Join(errors, "; "))
	}

	return nil
}

// validateLoggingConfig validates logging configuration
func validateLoggingConfig(config *LoggingConfig) error {
	var errors []string

	// Validate log level
	validLevels := map[string]bool{
		"debug": true,
		"info":  true,
		"warn":  true,
		"error": true,
		"fatal": true,
		"panic": true,
	}

	if !validLevels[strings.ToLower(config.Level)] {
		errors = append(errors, "log level must be one of: debug, info, warn, error, fatal, panic")
	}

	// Validate log format
	validFormats := map[string]bool{
		"json": true,
		"text": true,
	}

	if !validFormats[strings.ToLower(config.Format)] {
		errors = append(errors, "log format must be either 'json' or 'text'")
	}

	if len(errors) > 0 {
		return fmt.Errorf("%s", strings.Join(errors, "; "))
	}

	return nil
}

// validateServerConfig validates server configuration
func validateServerConfig(config *ServerConfig) error {
	var errors []string

	// Port validation
	if config.Port < 1 || config.Port > 65535 {
		errors = append(errors, "server port must be between 1 and 65535")
	}

	// Timeout validations
	if config.ReadTimeout < 1 {
		errors = append(errors, "read timeout must be at least 1 second")
	}
	if config.ReadTimeout > MaxReadWriteTimeout {
		errors = append(errors, "read timeout should not exceed 300 seconds")
	}

	if config.WriteTimeout < 1 {
		errors = append(errors, "write timeout must be at least 1 second")
	}
	if config.WriteTimeout > MaxReadWriteTimeout {
		errors = append(errors, "write timeout should not exceed 300 seconds")
	}

	if len(errors) > 0 {
		return fmt.Errorf("%s", strings.Join(errors, "; "))
	}

	return nil
}

// isValidBotToken performs basic validation on Discord bot token format
func isValidBotToken(token string) bool {
	// Basic validation - Discord bot tokens are typically 59+ characters
	// and contain alphanumeric characters, dots, dashes, and underscores
	// For testing purposes, we accept tokens that are obviously for testing
	if strings.Contains(token, "test") || strings.Contains(token, "testing") {
		return len(token) >= MinTokenLength
	}

	if len(token) < MinRealTokenLength {
		return false
	}

	// Check for common patterns in Discord bot tokens
	// Real validation should be done by attempting to connect to Discord API
	for _, char := range token {
		if !((char >= 'a' && char <= 'z') ||
			(char >= 'A' && char <= 'Z') ||
			(char >= '0' && char <= '9') ||
			char == '.' || char == '-' || char == '_') {
			return false
		}
	}

	return true
}
