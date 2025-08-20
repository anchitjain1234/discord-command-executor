package config

import (
	"fmt"
	"strings"

	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

// Default configuration constants
const (
	// Default timeouts in seconds
	DefaultDockerTimeout = 30
	DefaultMaxRuntime    = 300 // 5 minutes
)

// Config represents the application configuration
type Config struct {
	// Bot configuration
	Bot BotConfig `mapstructure:"bot"`

	// Docker configuration
	Docker DockerConfig `mapstructure:"docker"`

	// Logging configuration
	Logging LoggingConfig `mapstructure:"logging"`

	// Server configuration
	Server ServerConfig `mapstructure:"server"`
}

// BotConfig holds Discord bot specific configuration
type BotConfig struct {
	// Discord bot token (required)
	Token string `mapstructure:"token"`

	// Command prefix for bot commands
	Prefix string `mapstructure:"prefix"`

	// Guild ID for slash commands (optional, for development)
	GuildID string `mapstructure:"guild_id"`

	// Maximum concurrent command executions
	MaxConcurrentCommands int `mapstructure:"max_concurrent_commands"`
}

// DockerConfig holds Docker runtime configuration
type DockerConfig struct {
	// Docker host endpoint
	Host string `mapstructure:"host"`

	// Network name for containers
	NetworkName string `mapstructure:"network_name"`

	// CPU limit for containers (as fraction of CPU)
	CPULimit float64 `mapstructure:"cpu_limit"`

	// Default timeout for container operations (in seconds)
	DefaultTimeout int `mapstructure:"default_timeout"`

	// Maximum container runtime (in seconds)
	MaxRuntime int `mapstructure:"max_runtime"`

	// Memory limit for containers (in MB)
	MemoryLimit int `mapstructure:"memory_limit"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	// Log level (debug, info, warn, error)
	Level string `mapstructure:"level"`

	// Log format (json, text)
	Format string `mapstructure:"format"`

	// Log output file path (optional, defaults to stdout)
	OutputFile string `mapstructure:"output_file"`

	// Whether to include caller information in logs
	ReportCaller bool `mapstructure:"report_caller"`
}

// ServerConfig holds server-specific configuration
type ServerConfig struct {
	// Server host
	Host string `mapstructure:"host"`

	// Server port
	Port int `mapstructure:"port"`

	// Read timeout (in seconds)
	ReadTimeout int `mapstructure:"read_timeout"`

	// Write timeout (in seconds)
	WriteTimeout int `mapstructure:"write_timeout"`
}

// Load loads configuration from environment variables, config files, and CLI flags
func Load() (*Config, error) {
	// Set default configuration values
	setDefaults()

	// Configure Viper
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")
	viper.AddConfigPath("/etc/discord-command-executor")

	// Enable environment variable support
	viper.AutomaticEnv()
	viper.SetEnvPrefix("DCE") // DCE_BOT_TOKEN, DCE_DOCKER_HOST, etc.
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Bind specific environment variables to ensure they're picked up during unmarshal
	// This is necessary because viper's AutomaticEnv() doesn't always work with Unmarshal()
	envBindings := []string{
		"bot.token",
		"bot.prefix",
		"bot.guild_id",
		"bot.max_concurrent_commands",
		"docker.host",
		"docker.default_timeout",
		"docker.max_runtime",
		"docker.memory_limit",
		"docker.cpu_limit",
		"docker.network_name",
		"logging.level",
		"logging.format",
		"logging.output_file",
		"logging.report_caller",
		"server.host",
		"server.port",
		"server.read_timeout",
		"server.write_timeout",
	}

	for _, key := range envBindings {
		if err := viper.BindEnv(key); err != nil {
			return nil, fmt.Errorf("failed to bind environment variable for %s: %w", key, err)
		}
	}

	// Read configuration file if it exists
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found is not an error - we can use defaults and env vars
		logrus.Info("No config file found, using defaults and environment variables")
	} else {
		logrus.WithField("file", viper.ConfigFileUsed()).Info("Loaded configuration file")
	}

	// Unmarshal configuration
	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal configuration: %w", err)
	}

	// Validate configuration
	if err := validateConfig(&config); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	// Bot defaults
	viper.SetDefault("bot.prefix", "!")
	viper.SetDefault("bot.max_concurrent_commands", 10)

	// Docker defaults
	viper.SetDefault("docker.host", "unix:///var/run/docker.sock")
	viper.SetDefault("docker.default_timeout", DefaultDockerTimeout)
	viper.SetDefault("docker.max_runtime", DefaultMaxRuntime)
	viper.SetDefault("docker.memory_limit", 128) // 128 MB
	viper.SetDefault("docker.cpu_limit", 0.5)    // 50% of one CPU
	viper.SetDefault("docker.network_name", "discord-executor")

	// Logging defaults
	viper.SetDefault("logging.level", "info")
	viper.SetDefault("logging.format", "text")
	viper.SetDefault("logging.report_caller", false)

	// Server defaults
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.read_timeout", 10)
	viper.SetDefault("server.write_timeout", 10)
}
