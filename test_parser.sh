#!/bin/bash

# Extract just the parse_ai_response_to_operations function from int.sh
# This avoids running the main loop

# Create a temporary file with just the function
temp_func=$(mktemp)
sed -n '/^parse_ai_response_to_operations()/,/^}/p' /home/champi/Dev/thinkai_cli/int.sh > "$temp_func"

# Source the function
source "$temp_func"

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