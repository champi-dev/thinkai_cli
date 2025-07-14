# ThinkAI CLI - Enhanced with Agentic Mode & Context Awareness

## 🚀 What's New

The ThinkAI CLI has been transformed into a powerful agentic coding assistant with:

### 🤖 **Agentic Mode** (Default: ON)
- Automatically extracts and executes code from AI responses
- Creates files with intelligent naming
- Runs commands mentioned by the AI
- No more copy-pasting!

### 🧠 **Context Awareness**
- Analyzes your entire codebase automatically
- Maintains conversation context across sessions
- Provides AI with deep understanding of your project
- Intelligently retrieves relevant files

### 📝 **Enhanced Features**
- Conversation persistence with full history
- Project-aware responses
- Automatic file operations
- Command execution with visual feedback

## 🎯 Quick Start

```bash
# Start the enhanced CLI
./int.sh

# The CLI will:
# 1. Analyze your codebase (if in a project directory)
# 2. Enable agentic mode by default
# 3. Maintain conversation context

# Example usage:
> Create an Express server with authentication

# Watch as it:
# - Creates server.js
# - Creates package.json
# - Runs npm install
# - Shows you where everything was created!
```

## 📚 Key Commands

- `/analyze` - Manually analyze the current codebase
- `/context` - View codebase analysis summary
- `/new` - Start a new conversation
- `/list` - List all conversations
- `/switch <id>` - Switch to a different conversation
- `/history` - View conversation history
- `/clear` - Clear the screen

## 🔧 Configuration

### Agentic Mode
```bash
# Disable agentic mode (show responses only)
export CLIII_AGENTIC_MODE=false

# Re-enable agentic mode
export CLIII_AGENTIC_MODE=true
```

### Auto-Analysis
```bash
# Disable automatic codebase analysis
export CLIII_AUTO_ANALYZE=false
```

## 📊 How It Works

### 1. Codebase Analysis
When you start in a project directory, the CLI:
- Scans all code files (JS, Python, Go, etc.)
- Extracts imports, functions, and classes
- Creates a searchable index
- Updates every 24 hours

### 2. Context Enhancement
For each message, the CLI:
- Retrieves conversation history
- Searches for relevant files
- Includes file contents in AI context
- Ensures contextually aware responses

### 3. Agentic Execution
When AI responds with code/commands:
- Extracts code blocks with language detection
- Determines appropriate filenames
- Creates files automatically
- Executes shell commands
- Provides visual feedback

## 🧪 Testing

Run comprehensive tests:
```bash
# Run all tests
./test/run_all_tests.sh

# Individual test suites
./test/test_unit_functions.sh      # Unit tests
./test/test_context_continuity.sh  # E2E context tests
./test/test_full_workflow.sh       # Integration tests
```

## 📁 Project Structure

```
thinkai_cli/
├── int.sh                    # Main CLI script (enhanced)
├── test/
│   ├── run_all_tests.sh     # Master test runner
│   ├── test_unit_functions.sh
│   ├── test_context_continuity.sh
│   └── test_full_workflow.sh
├── AGENTIC_MODE.md          # Agentic mode documentation
├── CONTEXT_AWARENESS.md     # Context system documentation
└── DEMO_USAGE.md           # Quick demo guide
```

## 🎨 Example Workflows

### Creating a Web Server
```bash
> Create a Node.js web server with routing

# CLI will:
# 1. Create server.js with Express code
# 2. Create package.json with dependencies
# 3. Run npm install automatically
# 4. Show you the created files
```

### Optimizing Existing Code
```bash
> Optimize the fibonacci function in my project

# CLI will:
# 1. Find files containing fibonacci
# 2. Understand the current implementation
# 3. Suggest optimizations with full context
# 4. Create optimized version automatically
```

### Adding Features
```bash
> Add user authentication to my Express server

# CLI will:
# 1. Analyze your current server structure
# 2. Create auth middleware files
# 3. Update your server.js
# 4. Install required packages
```

## 🛡️ Safety Features

- Shows all operations before execution
- File paths are displayed clearly
- Commands are shown before running
- Conversation history is preserved
- No destructive operations without confirmation

## 🤝 Contributing

The enhanced CLI includes:
- Comprehensive test coverage
- Modular function design
- Clear documentation
- Extensible architecture

## 📝 License

Same as original ThinkAI CLI

---

**Note**: This is an enhanced version of the ThinkAI CLI with agentic capabilities and context awareness. The original functionality remains intact, with powerful new features added on top.