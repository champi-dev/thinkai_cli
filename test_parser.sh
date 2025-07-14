#!/bin/bash

# Extract necessary functions from int.sh without running the main loop

# Function to parse AI response to operations
parse_ai_response_to_operations() {
    local response_text=$1
    local operations_json="[]"
    
    # Save response to temp file for easier processing
    local temp_response=$(mktemp)
    echo "$response_text" > "$temp_response"
    
    # Extract code blocks with improved pattern matching
    local in_code_block=false
    local current_lang=""
    local current_code=""
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Check for code block start
        if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]+)?$ ]]; then
            if [[ "$in_code_block" == "false" ]]; then
                in_code_block=true
                current_lang="${BASH_REMATCH[1]:-plaintext}"
                current_code=""
            else
                # End of code block - process it
                in_code_block=false
                if [[ -n "$current_code" ]]; then
                    local filename=""
                    
                    # Determine filename based on language and content
                    case "$current_lang" in
                        javascript|js)
                            # Look for specific patterns in code
                            if [[ "$current_code" =~ express|app\.listen ]]; then
                                filename="server.js"
                            elif [[ "$current_code" =~ \"name\".*\"version\".*\"dependencies\" ]]; then
                                filename="package.json"
                            else
                                filename="app.js"
                            fi
                            ;;
                        json)
                            if [[ "$current_code" =~ \"name\".*\"version\".*\"dependencies\" ]]; then
                                filename="package.json"
                            elif [[ "$current_code" =~ \"compilerOptions\" ]]; then
                                filename="tsconfig.json"
                            else
                                filename="config.json"
                            fi
                            ;;
                        python|py)
                            if [[ "$current_code" =~ __name__.*==.*__main__ ]]; then
                                filename="main.py"
                            elif [[ "$current_code" =~ from[[:space:]]+flask|from[[:space:]]+django ]]; then
                                filename="app.py"
                            else
                                filename="script.py"
                            fi
                            ;;
                        sh|bash)
                            filename="script.sh"
                            ;;
                        html)
                            filename="index.html"
                            ;;
                        css)
                            filename="styles.css"
                            ;;
                        typescript|ts)
                            if [[ "$current_code" =~ express|app\.listen ]]; then
                                filename="server.ts"
                            else
                                filename="app.ts"
                            fi
                            ;;
                        env|dotenv)
                            filename=".env"
                            ;;
                        *)
                            # Try to infer from the response context
                            if [[ -n "$current_lang" && "$current_lang" != "plaintext" ]]; then
                                filename="file.$current_lang"
                            fi
                            ;;
                    esac
                    
                    # Add file operation if we have a filename
                    if [[ -n "$filename" ]]; then
                        # Properly escape the content for JSON
                        local escaped_content=$(echo "$current_code" | jq -Rs .)
                        local op=$(jq -n --arg path "$filename" --argjson content "$escaped_content" \
                            '{type: "file", operation: "write", path: $path, content: $content}')
                        operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
                    fi
                fi
                current_code=""
                current_lang=""
            fi
        elif [[ "$in_code_block" == "true" ]]; then
            # Inside code block - accumulate code
            if [[ -n "$current_code" ]]; then
                current_code+=$'\n'
            fi
            current_code+="$line"
        fi
    done < "$temp_response"
    
    # Extract shell commands more intelligently
    # First, look for commands in backticks
    local backtick_commands=$(grep -oE '`[^`]+`' "$temp_response" | sed 's/`//g')
    
    # Then look for command patterns in plain text
    local plain_commands=$(grep -E '^[[:space:]]*(npm|yarn|node|python|pip|git|mkdir|cd|ls|cat|echo|touch|cp|mv|rm|make|./|bash|sh)[[:space:]]+' "$temp_response" | \
        grep -v '```' | \
        sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
    
    # Also look for "run" commands that should be translated to node/python
    local run_commands=$(grep -E '(run|execute|start)[[:space:]]+[a-zA-Z0-9_.-]+\.(js|py|sh|rb)' "$temp_response" | \
        sed 's/.*\(run\|execute\|start\)[[:space:]]\+//' | \
        sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g' | \
        while read -r file; do
            case "$file" in
                *.js) echo "node $file" ;;
                *.py) echo "python $file" ;;
                *.sh) echo "bash $file" ;;
                *.rb) echo "ruby $file" ;;
            esac
        done)
    
    # Combine and deduplicate commands
    local all_commands=$(echo -e "$backtick_commands\n$plain_commands\n$run_commands" | sort -u)
    
    # Process commands
    while IFS= read -r cmd; do
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
        if [[ -n "$cmd" ]]; then
            # Filter out invalid commands
            if [[ "$cmd" =~ ^(npm|yarn|node|python|pip|git|mkdir|cd|ls|cat|echo|touch|cp|mv|rm|make|bash|sh|\./|pnpm|bun|deno) ]]; then
                # Skip if it's just a mention, not a command
                if [[ ! "$cmd" =~ (the|a|an|with|using|via|like|such|called)[[:space:]]+(npm|yarn|node|python|pip|git) ]]; then
                    # Special handling for npm/yarn commands
                    if [[ "$cmd" =~ ^(npm|yarn|pnpm|bun)[[:space:]]+(init|install|i|add|remove|run|start|test|build) ]]; then
                        local op=$(jq -n --arg cmd "$cmd" '{type: "command", command: $cmd}')
                        operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
                    # Handle other commands
                    elif [[ ! "$cmd" =~ ^(npm|yarn|pnpm|bun) ]]; then
                        local op=$(jq -n --arg cmd "$cmd" '{type: "command", command: $cmd}')
                        operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
                    fi
                fi
            fi
        fi
    done <<< "$all_commands"
    
    # Clean up
    rm -f "$temp_response"
    
    # Return operations if any were found
    if [[ $(echo "$operations_json" | jq 'length') -gt 0 ]]; then
        echo "$operations_json"
    fi
}

# Test response that simulates what the AI might return
test_response='I'\''ll create an Express server with authentication for you.

First, let'\''s initialize the project:

```json
{
  "name": "express-auth-server",
  "version": "1.0.0",
  "description": "Express server with JWT authentication",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "jsonwebtoken": "^9.0.0",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.0.0"
  }
}
```

Now here'\''s the server code:

```javascript
const express = require('\''express'\'');
const jwt = require('\''jsonwebtoken'\'');
const bcrypt = require('\''bcryptjs'\'');

const app = express();
app.use(express.json());

// Mock user database
const users = [];

// Register endpoint
app.post('\''/register'\'', async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  users.push({ username, password: hashedPassword });
  res.json({ message: '\''User registered successfully'\'' });
});

// Login endpoint
app.post('\''/login'\'', async (req, res) => {
  const { username, password } = req.body;
  const user = users.find(u => u.username === username);
  
  if (user && await bcrypt.compare(password, user.password)) {
    const token = jwt.sign({ username }, '\''secret-key'\'', { expiresIn: '\''1h'\'' });
    res.json({ token });
  } else {
    res.status(401).json({ message: '\''Invalid credentials'\'' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

To get started, run these commands:
- `npm init -y`
- `npm install express jsonwebtoken bcryptjs dotenv`

Then start the server with `npm start`'

# Test the parser
echo "Testing agentic mode parser..."
echo "==============================="

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Please install it: sudo apt-get install jq"
    exit 1
fi

# Parse the test response
operations=$(parse_ai_response_to_operations "$test_response")

# Display results
if [[ -n "$operations" ]]; then
    echo "✅ Parser found operations:"
    echo "$operations" | jq '.'
    
    echo -e "\n📊 Summary:"
    echo "Total operations: $(echo "$operations" | jq 'length')"
    echo "File operations: $(echo "$operations" | jq '[.[] | select(.type == "file")] | length')"
    echo "Command operations: $(echo "$operations" | jq '[.[] | select(.type == "command")] | length')"
    
    echo -e "\n📁 Files to be created:"
    echo "$operations" | jq -r '.[] | select(.type == "file") | "  - " + .path'
    
    echo -e "\n💻 Commands to be executed:"
    echo "$operations" | jq -r '.[] | select(.type == "command") | "  - " + .command'
else
    echo "❌ No operations found"
fi

# Cleanup
rm -f "$temp_func"