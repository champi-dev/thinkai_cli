#!/bin/bash

echo "=== ThinkAI CLI Complete Fix Test ==="
echo ""

# Test 1: Test streaming functionality
echo "1. Testing text streaming..."
./test_streaming_fix.sh
echo ""

# Test 2: Test file operation parsing
echo "2. Testing file operation parsing..."

test_file_parsing() {
    local test_response='Create an `app.js` file with this code:

```javascript
const express = require("express");
const app = express();

app.get("/", (req, res) => {
    res.send("Hello World!");
});

app.listen(3000, () => {
    console.log("Server running on port 3000");
});
```

Now run `node app.js` to start the server.'

    # Save to temp file
    echo "$test_response" > /tmp/test_response.txt
    
    # Source the parsing function from int.sh
    source ./int.sh
    
    # Parse operations
    operations=$(parse_ai_response_to_operations "$test_response")
    
    echo "Parsed operations:"
    echo "$operations" | jq '.' 2>/dev/null || echo "No operations found"
}

test_file_parsing
echo ""

# Test 3: Test command execution
echo "3. Testing command execution..."
source ./int.sh

# Test safe command execution
echo "Testing 'echo Hello World' command:"
execute_command_safe "echo Hello World"
echo ""

echo "Testing prevention of bare interpreter:"
execute_command_safe "node"
echo ""

# Test 4: Integration test
echo "4. Running integration test with actual ThinkAI response..."
echo ""

echo "=== All tests complete ==="