# Quick Demo: Using the Enhanced ThinkAI CLI

## How to Test the Agentic Mode

1. **Start the CLI with agentic mode enabled (default)**:
   ```bash
   ./int.sh
   ```

2. **Ask it to create something**, for example:
   ```
   > Create an Express server with user authentication
   ```

3. **Watch as the CLI**:
   - Shows the AI's explanation
   - Displays "🤖 Agentic mode: Found X operations to execute"
   - Automatically creates files (server.js, package.json, etc.)
   - Executes commands (npm init, npm install, etc.)

## What Happens Behind the Scenes

When you ask for an Express server, the enhanced CLI:

1. **Parses the AI response** to find code blocks like:
   ````
   ```javascript
   const express = require('express');
   // ... server code ...
   ```
   ````

2. **Intelligently names files**:
   - JavaScript with `express` → `server.js`
   - JSON with `"dependencies"` → `package.json`
   - Python with `__main__` → `main.py`

3. **Extracts commands** from text like:
   - "Run `npm install express`"
   - "Execute npm init -y"
   - Commands in backticks

4. **Executes everything automatically**!

## Example Session

```bash
$ ./int.sh
Welcome to ThinkAI CLI with conversation persistence!
Commands: /new, /list, /switch <id>, /history, /clear, exit
🤖 Agentic mode enabled - I'll automatically execute code and commands from AI responses
To disable: export CLIII_AGENTIC_MODE=false
Current conversation: conv_20250714_123456_1234

> Create a simple web server with Node.js

[AI responds with explanation and code...]

🤖 Agentic mode: Found 3 operations to execute

✓ File server.js has been written
✓ File package.json has been written
Executing command: npm install
✓ Command executed successfully

> exit
```

## Files Created

After running the above, you'll have:
```
./
├── server.js       # Your Express server code
├── package.json    # Dependencies and scripts
└── node_modules/   # Installed packages
```

## Disable Agentic Mode

If you just want to see responses without automatic execution:
```bash
export CLIII_AGENTIC_MODE=false
./int.sh
```

## Tips

- Be specific in your requests for better results
- The CLI shows all operations before executing
- All conversations are saved in `~/.cliii/conversations/`
- Use `/list` to see all your conversations
- Use `/history` to review what was done