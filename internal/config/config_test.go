package config

import (
	"os"
	"strings"
	"testing"

	"github.com/spf13/viper"
)

func TestLoadConfigDefaults(t *testing.T) {
	// Set required environment variable for testing
	os.Setenv("DCE_BOT_TOKEN", "test.token.for.testing.purposes.only.this.is.not.real")
	defer os.Unsetenv("DCE_BOT_TOKEN")

	// Create a new Viper instance for this test to avoid global state issues
	v := viper.New()

	// Set default configuration values
	v.SetDefault("bot.prefix", "!")
	v.SetDefault("bot.max_concurrent_commands", 10)
	v.SetDefault("docker.host", "unix:///var/run/docker.sock")
	v.SetDefault("docker.default_timeout", 30)
	v.SetDefault("docker.max_runtime", 300)
	v.SetDefault("docker.memory_limit", 128)
	v.SetDefault("docker.cpu_limit", 0.5)
	v.SetDefault("docker.network_name", "discord-executor")
	v.SetDefault("logging.level", "info")
	v.SetDefault("logging.format", "text")
	v.SetDefault("logging.report_caller", false)
	v.SetDefault("server.host", "0.0.0.0")
	v.SetDefault("server.port", 8080)
	v.SetDefault("server.read_timeout", 10)
	v.SetDefault("server.write_timeout", 10)

	// Configure Viper
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./configs")
	v.AddConfigPath(".")

	// Enable environment variable support
	v.AutomaticEnv()
	v.SetEnvPrefix("DCE")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Bind specific environment variables to ensure they're picked up during unmarshal
	v.BindEnv("bot.token", "DCE_BOT_TOKEN")

	// Try to read config file (it's OK if it doesn't exist)
	v.ReadInConfig()

	// Unmarshal configuration
	var config Config
	if err := v.Unmarshal(&config); err != nil {
		t.Fatalf("Failed to unmarshal configuration: %v", err)
	}

	// Validate configuration
	if err := validateConfig(&config); err != nil {
		t.Fatalf("Failed to validate config: %v", err)
	}

	// Test that defaults are properly set
	if config.Bot.Prefix != "!" {
		t.Errorf("Expected default prefix '!', got '%s'", config.Bot.Prefix)
	}

	if config.Bot.MaxConcurrentCommands != 10 {
		t.Errorf("Expected default max concurrent commands 10, got %d", config.Bot.MaxConcurrentCommands)
	}

	if config.Docker.Host != "unix:///var/run/docker.sock" {
		t.Errorf("Expected default Docker host 'unix:///var/run/docker.sock', got '%s'", config.Docker.Host)
	}

	if config.Logging.Level != "info" {
		t.Errorf("Expected default log level 'info', got '%s'", config.Logging.Level)
	}

	if config.Server.Port != 8080 {
		t.Errorf("Expected default server port 8080, got %d", config.Server.Port)
	}
}

func TestValidateRequiredFields(t *testing.T) {
	tests := []struct {
		name      string
		config    Config
		shouldErr bool
	}{
		{
			name: "valid config",
			config: Config{
				Bot: BotConfig{
					Token:                 "valid.test.token.for.unit.testing.purposes.only.not.real",
					Prefix:                "!",
					MaxConcurrentCommands: 5,
				},
				Docker: DockerConfig{
					Host:           "unix:///var/run/docker.sock",
					DefaultTimeout: 30,
					MaxRuntime:     300,
					MemoryLimit:    128,
					CPULimit:       0.5,
					NetworkName:    "test-network",
				},
				Logging: LoggingConfig{
					Level:  "info",
					Format: "text",
				},
				Server: ServerConfig{
					Host:         "localhost",
					Port:         8080,
					ReadTimeout:  10,
					WriteTimeout: 10,
				},
			},
			shouldErr: false,
		},
		{
			name: "missing bot token",
			config: Config{
				Bot: BotConfig{
					Prefix:                "!",
					MaxConcurrentCommands: 5,
				},
				Docker: DockerConfig{
					Host:           "unix:///var/run/docker.sock",
					DefaultTimeout: 30,
					MaxRuntime:     300,
					MemoryLimit:    128,
					CPULimit:       0.5,
					NetworkName:    "test-network",
				},
				Logging: LoggingConfig{
					Level:  "info",
					Format: "text",
				},
				Server: ServerConfig{
					Host:         "localhost",
					Port:         8080,
					ReadTimeout:  10,
					WriteTimeout: 10,
				},
			},
			shouldErr: true,
		},
		{
			name: "invalid log level",
			config: Config{
				Bot: BotConfig{
					Token:                 "valid.test.token.for.unit.testing.purposes.only.not.real",
					Prefix:                "!",
					MaxConcurrentCommands: 5,
				},
				Docker: DockerConfig{
					Host:           "unix:///var/run/docker.sock",
					DefaultTimeout: 30,
					MaxRuntime:     300,
					MemoryLimit:    128,
					CPULimit:       0.5,
					NetworkName:    "test-network",
				},
				Logging: LoggingConfig{
					Level:  "invalid",
					Format: "text",
				},
				Server: ServerConfig{
					Host:         "localhost",
					Port:         8080,
					ReadTimeout:  10,
					WriteTimeout: 10,
				},
			},
			shouldErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateConfig(&tt.config)
			if tt.shouldErr && err == nil {
				t.Error("Expected validation error, but got none")
			}
			if !tt.shouldErr && err != nil {
				t.Errorf("Expected no validation error, but got: %v", err)
			}
		})
	}
}

func TestEnvironmentVariableOverrides(t *testing.T) {
	// Set environment variables
	os.Setenv("DCE_BOT_TOKEN", "env.test.token.for.testing.purposes.only.not.real")
	os.Setenv("DCE_BOT_PREFIX", ">>")
	os.Setenv("DCE_DOCKER_HOST", "tcp://localhost:2376")
	os.Setenv("DCE_LOGGING_LEVEL", "debug")
	defer func() {
		os.Unsetenv("DCE_BOT_TOKEN")
		os.Unsetenv("DCE_BOT_PREFIX")
		os.Unsetenv("DCE_DOCKER_HOST")
		os.Unsetenv("DCE_LOGGING_LEVEL")
	}()

	config, err := Load()
	if err != nil {
		t.Fatalf("Failed to load config: %v", err)
	}

	// Test that environment variables override defaults
	if config.Bot.Token != "env.test.token.for.testing.purposes.only.not.real" {
		t.Errorf("Expected bot token from env, got '%s'", config.Bot.Token)
	}

	if config.Bot.Prefix != ">>" {
		t.Errorf("Expected prefix from env '>>', got '%s'", config.Bot.Prefix)
	}

	if config.Docker.Host != "tcp://localhost:2376" {
		t.Errorf("Expected Docker host from env 'tcp://localhost:2376', got '%s'", config.Docker.Host)
	}

	if config.Logging.Level != "debug" {
		t.Errorf("Expected log level from env 'debug', got '%s'", config.Logging.Level)
	}
}
