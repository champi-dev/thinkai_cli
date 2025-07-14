#!/bin/bash

# Debug the parsing issue

# Source just the parsing function
source <(sed -n '/^parse_ai_response_to_operations()/,/^}/p' ./int.sh)

# Test with the actual API response format
test_response='Certainly! Below is a simple `index.js` file in JavaScript that will print "Hello from ThinkAI" to the console when you run it:

```javascript
// index.js
console.log("Hello from ThinkAI");
```

To run this script, you can use Node.js.'

echo "=== Debug Parser Test ==="
echo ""
echo "Input text sample (first 200 chars):"
echo "$test_response" | head -c 200
echo "..."
echo ""

# Save to temp file and check for backticks
temp_file=$(mktemp)
echo "$test_response" > "$temp_file"

echo "Checking for code block markers:"
if grep -n '```' "$temp_file"; then
    echo "✅ Found code block markers"
else
    echo "❌ No code block markers found"
fi

echo ""
echo "Hex dump of backticks area:"
echo "$test_response" | grep -A2 -B2 '```' | od -c | head -5

echo ""
echo "Running parser..."
operations=$(parse_ai_response_to_operations "$test_response")

if [[ -n "$operations" ]]; then
    echo "✅ Operations found:"
    echo "$operations" | jq '.'
else
    echo "❌ No operations found"
fi

rm -f "$temp_file"