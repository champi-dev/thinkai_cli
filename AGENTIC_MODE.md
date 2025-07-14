# ThinkAI CLI - Agentic Mode

## Overview

The enhanced ThinkAI CLI now includes **Agentic Mode** - a powerful feature that automatically extracts and executes code blocks and commands from AI responses. Instead of just showing you how to create something, the CLI will actually create it for you!

## How It Works

When you ask the AI to create something (like an Express server), the agentic mode will:

1. **Extract Code Blocks**: Automatically detects code blocks in the AI response
2. **Smart File Naming**: Intelligently determines appropriate filenames based on:
   - Language identifier (js, python, html, etc.)
   - Code content patterns (e.g., detects Express servers, package.json files)
   - Context clues from the AI response
3. **Execute Commands**: Extracts and runs shell commands mentioned in the response
4. **Visual Feedback**: Shows you what operations are being performed

## Usage

### Enable Agentic Mode (Default)
```bash
# Agentic mode is enabled by default
./int.sh

# Or explicitly enable it
export CLIII_AGENTIC_MODE=true
./int.sh
```

### Disable Agentic Mode
```bash
# Disable for current session
export CLIII_AGENTIC_MODE=false
./int.sh
```

## Examples

### Example 1: Create an Express Server
```bash
> Create an Express server with user authentication
```

The CLI will:
- Create `server.js` with the Express server code
- Create `package.json` with dependencies
- Execute `npm init -y` and `npm install express jsonwebtoken bcryptjs`
- Show you where files were created

### Example 2: Create a Python Flask App
```bash
> Create a Flask API with CRUD operations
```

The CLI will:
- Create `app.py` with Flask application code
- Create `requirements.txt` with dependencies
- Execute `pip install -r requirements.txt`

### Example 3: Create a React Component
```bash
> Create a React component for a todo list
```

The CLI will:
- Create component files with appropriate names
- Create any CSS files mentioned
- Execute any npm commands for additional packages

## File Naming Intelligence

The CLI uses smart pattern matching to determine filenames:

| Language | Patterns Detected | Default Filename |
|----------|------------------|------------------|
| JavaScript | `express`, `app.listen` | `server.js` |
| JavaScript | `"name"`, `"dependencies"` | `package.json` |
| Python | `__name__ == "__main__"` | `main.py` |
| Python | `from flask`, `from django` | `app.py` |
| TypeScript | `express` with `.ts` | `server.ts` |
| HTML | Any HTML code | `index.html` |
| CSS | Any CSS code | `styles.css` |
| Bash/Shell | Shell scripts | `script.sh` |
| JSON | `"compilerOptions"` | `tsconfig.json` |
| Env | Environment variables | `.env` |

## Command Extraction

The CLI intelligently extracts commands from:
- Backtick-wrapped commands: `npm install`
- Command patterns in text: "Run npm install express"
- Common command prefixes: npm, yarn, pip, git, mkdir, etc.

## Safety Features

- Commands are shown before execution
- File operations show target paths
- All operations are logged to conversation history
- You can disable agentic mode at any time

## Troubleshooting

### Operations Not Executing
1. Check if agentic mode is enabled: Look for the 🤖 icon at startup
2. Ensure `jq` is installed: `sudo apt-get install jq`
3. Check the AI response contains proper code blocks with ``` markers

### Wrong Filenames
The CLI makes intelligent guesses, but you can always:
1. Rename files after creation
2. Specify filenames in your prompt: "Create server.js with Express code"

### Commands Not Running
- Ensure commands are clearly stated in the AI response
- Commands should be in backticks or on their own lines
- Common commands are recognized: npm, yarn, pip, git, etc.

## Advanced Configuration

You can customize behavior by modifying the `parse_ai_response_to_operations` function in `int.sh`:
- Add new language patterns
- Customize filename detection
- Add new command patterns
- Modify operation handling

## Best Practices

1. **Be Specific**: "Create an Express server in server.js" works better than just "make a server"
2. **Review Operations**: The CLI shows what it's about to do - review before it executes
3. **Use Version Control**: Commit your work regularly when using agentic mode
4. **Test Incrementally**: Ask for smaller pieces to test as you go

## Limitations

- Code blocks must use proper ``` markdown syntax
- Commands must be recognizable shell commands
- File naming is based on heuristics and may need adjustment
- Large responses might be truncated by the API

## Future Enhancements

- [ ] Configuration file for custom patterns
- [ ] Interactive confirmation mode
- [ ] Dry-run mode to preview operations
- [ ] Custom file naming rules
- [ ] Multi-file project scaffolding