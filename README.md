# Discord Command Executor

A secure Discord bot that executes commands in isolated containerized environments, providing safe code execution and system command capabilities for Discord servers.

## Features

- **Secure Execution**: Commands run in isolated Docker containers with strict resource limits
- **Multi-Language Support**: Execute code in various programming languages (Python, JavaScript, Go, etc.)
- **Resource Management**: CPU, memory, and network restrictions prevent abuse
- **Discord Integration**: Seamless command handling through Discord slash commands
- **Audit Logging**: Complete execution history and security monitoring
- **Concurrent Execution**: Rate limiting and queue management for multiple simultaneous requests

## Architecture

The bot follows a modular Go architecture:

```
├── cmd/bot/                 # Application entry point
├── internal/
│   ├── bot/                # Discord bot implementation
│   ├── executor/           # Command execution engine
│   ├── config/             # Configuration management
│   └── handlers/           # Command handlers
├── pkg/                    # Public libraries
├── configs/                # Configuration files
└── scripts/                # Build and deployment scripts
```

## Security

- **Container Isolation**: Each command runs in a separate Docker container
- **Resource Limits**: Configurable CPU, memory, and execution time constraints
- **Network Isolation**: No external network access by default
- **Privilege Dropping**: Containers run with minimal required permissions
- **Command Filtering**: Whitelist/blacklist support for allowed commands

## Quick Start

### Prerequisites

- Go 1.21+
- Docker
- Discord Application with Bot Token

### Installation

```bash
# Clone the repository
git clone https://github.com/anchitjain1234/discord-command-executor.git
cd discord-command-executor

# Install dependencies
go mod download

# Build the application
go build -o bot cmd/bot/main.go
```

### Configuration

Create a `config.yaml` file:

```yaml
discord:
  token: "your-bot-token"
  guild_id: "your-guild-id"

executor:
  max_concurrent: 5
  timeout: 30s
  memory_limit: "128MB"
  cpu_limit: 0.5
```

### Running

```bash
./bot -config config.yaml
```

## Development

### Building

```bash
go build ./...
```

### Testing

```bash
go test ./...
```

### Linting

```bash
go vet ./...
golangci-lint run
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Safety Notice

This bot executes arbitrary code submitted by Discord users. Ensure proper security measures, monitoring, and access controls are in place before deploying to production environments.