# CLIII - Command Line Interface for ThinkAI 🚀

A smart terminal that remembers everything and can code for you!

## What is CLIII?

CLIII (pronounced "CLI-three") is like having a coding buddy in your terminal who:
- 🧠 **Remembers Everything**: All conversations are saved forever
- 💻 **Writes Code**: Creates files, edits code, runs commands
- 🔄 **Maintains Context**: Picks up where you left off
- 🛠️ **Executes Tasks**: Runs commands and manages your projects

## Quick Start

```bash
# Make it executable
chmod +x int.sh

# Start CLIII
./int.sh

# Start coding!
> Help me create a REST API for a todo list
```

## Features

### 💬 Persistent Conversations
- `/new` - Start a new conversation
- `/list` - See all your conversations  
- `/switch <id>` - Continue a previous conversation
- `/history` - View current conversation
- `/clear` - Clear screen (conversation stays)

### 🔧 For Software Development

CLIII can help you:
- **Generate Code**: "Create a user authentication system"
- **Debug Issues**: "Fix this TypeError in my React component"
- **Run Commands**: "Install express and create a server"
- **Manage Files**: "Create a project structure for my app"
- **Refactor Code**: "Convert this to use async/await"

### 📁 File Operations
- Write new files
- Edit existing files
- Append content
- Delete files
- Create directories
- Read file contents

### 🚀 Command Execution
- Run any shell command
- Install packages
- Start servers
- Run tests
- Execute builds

## How to Use for Coding Projects

See [CODING_WITH_CLIII.md](CODING_WITH_CLIII.md) for detailed examples!

### Example: Building a Web App

```bash
> Create an Express server with user authentication

# CLIII will:
# 1. Create project structure
# 2. Write server code
# 3. Set up routes
# 4. Add authentication
# 5. Install dependencies
# 6. Run the server

> Add a REST API for blog posts

# CLIII remembers your project context and adds to it!
```

## Installation

### Requirements
- Bash shell
- curl (for API calls)
- jq (recommended for JSON parsing)
- Internet connection

### Setup

```bash
git clone <repository>
cd thinkai_cli
chmod +x int.sh
./int.sh
```

## How It Works (Simple Explanation)

1. **You type a message** → 
2. **CLIII sends it to ThinkAI** (with last 10 messages for context) →
3. **AI responds** with text and/or instructions →
4. **CLIII executes** any file operations or commands →
5. **Everything is saved** in `~/.cliii/conversations/`

## Project Structure

```
~/.cliii/
├── conversations/           # All your saved conversations
│   ├── conv_20250714_093021_1234.json
│   └── ...
└── current_conversation    # Which conversation you're in
```

## Tips

1. **Be Specific**: "Create a REST API with Express, MongoDB, and JWT auth"
2. **Build Incrementally**: Start simple, add features one by one
3. **Use Context**: "Remember the auth system we built? Add role permissions"
4. **Review Code**: Always understand what CLIII creates
5. **Commit Often**: CLIII creates files, but you should use git

## Safety

- CLIII can execute any command you could run
- It has full access to your file system
- Always review commands before letting them run
- Use in a safe environment or container

## Testing

```bash
cd test
./run_all_tests.sh
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new features
4. Make sure all tests pass
5. Submit a pull request

## License

[Your License Here]

---

**Remember**: CLIII is a powerful tool. Use it wisely! 🎯