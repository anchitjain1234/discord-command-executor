package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/anchitjain1234/discord-command-executor/internal/config"
)

var (
	version   = "dev"
	buildTime = "unknown"
	gitCommit = "unknown"
)

func main() {
	var (
		configFile = flag.String("config", "config.yaml", "path to configuration file")
		showHelp   = flag.Bool("help", false, "show help message")
		showVer    = flag.Bool("version", false, "show version information")
		healthCmd  = flag.Bool("health", false, "health check command")
	)
	flag.Parse()

	if *showHelp {
		showHelpMessage()
		return
	}

	if *showVer {
		showVersion()
		return
	}

	if *healthCmd {
		healthCheck()
		return
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	fmt.Printf("Discord Command Executor v%s\n", version)
	fmt.Printf("Starting bot with config: %s\n", *configFile)
	fmt.Printf("Bot token configured: %t\n", cfg.Bot.Token != "")

	// TODO: Initialize and start the Discord bot
	// This is a placeholder until the actual bot implementation is ready
	fmt.Println("Bot initialization would happen here...")
	fmt.Println("Press Ctrl+C to stop")

	// Keep the application running
	select {}
}

func showHelpMessage() {
	fmt.Printf("Discord Command Executor v%s\n\n", version)
	fmt.Println("Usage:")
	fmt.Printf("  %s [options]\n\n", os.Args[0])
	fmt.Println("Options:")
	flag.PrintDefaults()
	fmt.Println("\nCommands:")
	fmt.Println("  health    Perform health check")
	fmt.Println("  version   Show version information")
}

func showVersion() {
	fmt.Printf("Discord Command Executor\n")
	fmt.Printf("Version:    %s\n", version)
	fmt.Printf("Build Time: %s\n", buildTime)
	fmt.Printf("Git Commit: %s\n", gitCommit)
}

func healthCheck() {
	// Basic health check - verify we can start
	fmt.Println("Health check: OK")
	os.Exit(0)
}
