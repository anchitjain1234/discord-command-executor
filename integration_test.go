package main

import (
	"os"
	"testing"

	"github.com/bwmarrin/discordgo"
	"github.com/docker/docker/client"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"github.com/anchitjain1234/discord-command-executor/internal/config"
)

// TestDependencyIntegration verifies that all core dependencies can be imported and instantiated
func TestDependencyIntegration(t *testing.T) {
	// Test that all dependencies can be imported and basic objects created

	// Test Discord library
	t.Run("Discord Library", func(t *testing.T) {
		// We can't actually connect without a real token, but we can verify the library loads
		session, err := discordgo.New("Bot fake-token-for-test")
		if err != nil {
			t.Fatalf("Failed to create Discord session: %v", err)
		}
		if session == nil {
			t.Fatal("Discord session is nil")
		}
	})

	// Test Docker client library
	t.Run("Docker Client", func(t *testing.T) {
		// Create a Docker client (won't actually connect in test)
		cli, err := client.NewClientWithOpts(client.FromEnv)
		if err != nil {
			t.Fatalf("Failed to create Docker client: %v", err)
		}
		if cli == nil {
			t.Fatal("Docker client is nil")
		}
		defer cli.Close()
	})

	// Test logging library
	t.Run("Logrus Logging", func(t *testing.T) {
		logger := logrus.New()
		if logger == nil {
			t.Fatal("Logger is nil")
		}

		// Test that we can set log level and format
		logger.SetLevel(logrus.InfoLevel)
		logger.SetFormatter(&logrus.JSONFormatter{})

		// Test logging (should not error)
		logger.Info("Test log message")
	})

	// Test Cobra CLI library
	t.Run("Cobra CLI", func(t *testing.T) {
		cmd := &cobra.Command{
			Use:   "test",
			Short: "A test command",
			Run: func(cmd *cobra.Command, args []string) {
				// Test command
			},
		}

		if cmd == nil {
			t.Fatal("Cobra command is nil")
		}

		// Test that we can add flags
		cmd.Flags().String("test-flag", "", "A test flag")
	})

	// Test Viper configuration library
	t.Run("Viper Configuration", func(t *testing.T) {
		v := viper.New()
		if v == nil {
			t.Fatal("Viper instance is nil")
		}

		// Test setting and getting configuration
		v.SetDefault("test.value", "default")
		if v.GetString("test.value") != "default" {
			t.Error("Failed to set/get default value")
		}
	})

	// Test our configuration package
	t.Run("Configuration Package", func(t *testing.T) {
		// Set minimal required environment variables
		os.Setenv("DCE_BOT_TOKEN", "test.token.for.integration.testing.only")
		defer os.Unsetenv("DCE_BOT_TOKEN")

		cfg, err := config.Load()
		if err != nil {
			t.Fatalf("Failed to load configuration: %v", err)
		}

		if cfg == nil {
			t.Fatal("Configuration is nil")
		}

		// Verify some basic configuration values
		if cfg.Bot.Token == "" {
			t.Error("Bot token should not be empty")
		}

		if cfg.Bot.Prefix != "!" {
			t.Errorf("Expected default prefix '!', got '%s'", cfg.Bot.Prefix)
		}

		if cfg.Docker.Host == "" {
			t.Error("Docker host should not be empty")
		}

		if cfg.Logging.Level == "" {
			t.Error("Logging level should not be empty")
		}
	})
}

// TestProjectBuild verifies that the project builds without errors
func TestProjectBuild(t *testing.T) {
	// This test exists to catch build issues in the CI environment
	// The actual compilation happens when running "go test"

	t.Run("Dependencies Resolve", func(t *testing.T) {
		// If we get here, all imports resolved successfully
		t.Log("All dependencies imported successfully")
	})
}
