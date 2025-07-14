# ThinkAI CLI

A smart command-line interface that leverages the ThinkAI API to create files, execute commands, and assist with development tasks using natural language.

## Features

- 🤖 **Smart AI Integration**: Leverages ThinkAI API for intelligent responses
- 📝 **Automatic File Creation**: Creates files based on natural language requests
- 🚀 **Command Execution**: Executes commands suggested by the AI
- 💬 **Conversation Memory**: Maintains context across sessions
- 🔍 **Codebase Analysis**: Analyzes and indexes your project structure
- ⚡ **Agentic Mode**: Automatically executes operations from AI responses

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/thinkai_cli.git
cd thinkai_cli

# Run the installer
chmod +x install.sh
./install.sh
```

### Manual Installation

1. Make the script executable:
```bash
chmod +x int.sh
```

2. Add to PATH (choose one):

**Option A: System-wide (requires sudo)**
```bash
sudo ln -s $(pwd)/int.sh /usr/local/bin/thinkai
```

**Option B: User-specific**
```bash
mkdir -p ~/.local/bin
ln -s $(pwd)/int.sh ~/.local/bin/thinkai

# Add to PATH if not already there
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

Simply type `thinkai` in your terminal:

```bash
thinkai
```

### Examples

1. **Create a file:**
```
> create a hello.js file that prints Hello World
```

2. **Build a web server:**
```
> create an express server with authentication
```

3. **Execute commands:**
```
> list all JavaScript files in the current directory
```

4. **Analyze codebase:**
```
> /analyze
```

### Commands

- `/new` - Start a new conversation
- `/list` - List all conversations
- `/switch <id>` - Switch to a different conversation
- `/history` - Show conversation history
- `/analyze` - Analyze current codebase
- `/context` - Show codebase context
- `exit` - Exit the CLI

## How It Works

ThinkAI CLI sends your requests to the ThinkAI API, which returns intelligent responses. When the AI suggests creating files or running commands, the CLI automatically:

1. Parses the AI response for code blocks and commands
2. Creates files with the suggested content
3. Executes safe commands
4. Shows you the results

## Configuration

### Environment Variables

- `CLIII_AGENTIC_MODE` - Enable/disable automatic execution (default: true)
- `DEBUG_MODE` - Enable debug output (default: false)
- `CLIII_STREAMING` - Enable streaming responses (default: true)

### Example

```bash
# Disable automatic execution
export CLIII_AGENTIC_MODE=false
thinkai

# Enable debug mode
export DEBUG_MODE=true
thinkai
```

## Smart Features

The CLI leverages ThinkAI API for:

- **Natural Language Understanding**: Understands requests in plain English
- **Code Generation**: Generates code in multiple languages
- **Command Suggestions**: Suggests appropriate commands for tasks
- **Error Analysis**: Analyzes and suggests fixes for errors
- **Context Awareness**: Maintains conversation context

## Safety

- Prevents execution of bare interpreter commands that would hang
- Confirms dangerous operations
- Creates backups before modifying files
- Validates commands before execution

## Dependencies

- `bash` 4.0+
- `curl` for API calls
- `jq` for JSON processing
- `node` (optional, for running JavaScript files)

## Troubleshooting

### Command not found
Make sure `~/.local/bin` is in your PATH:
```bash
echo $PATH
```

### API Connection Issues
Check your internet connection and that the API is accessible:
```bash
curl -I https://thinkai.lat
```

### Missing jq
Install jq for better JSON handling:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

MIT License - see LICENSE file for details