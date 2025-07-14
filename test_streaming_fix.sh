#!/bin/bash

# Test the streaming functionality
echo "Testing streaming text display..."

# Test the stream function directly
stream_colored_text() {
    local text=$1
    local color=${2:-"\033[1;36m"}
    local reset="\033[0m"
    
    # Enable immediate output
    stty -echo 2>/dev/null || true
    
    echo -ne "$color"
    while IFS= read -r -n1 char; do
        echo -n "$char"
        # Add small delay for streaming effect
        sleep 0.01 2>/dev/null || true
    done <<< "$text"
    echo -e "$reset"
    
    stty echo 2>/dev/null || true
}

# Test streaming
stream_colored_text "This text should appear character by character with a slight delay between each character!"
echo ""
echo "Streaming test complete!"

# Test file parsing
echo -e "\nTesting file parsing..."

parse_test_response() {
    local response_text="$1"
    
    # Create a test response with app.js code
    echo "Parsing response with JavaScript code..."
    
    # Test extraction
    if [[ "$response_text" =~ \`app\.js\` ]]; then
        echo "✓ Found app.js mention"
    fi
    
    # Check for code block
    if [[ "$response_text" =~ \`\`\`javascript ]]; then
        echo "✓ Found JavaScript code block"
    fi
}

# Test with sample response
test_response="Create an \`app.js\` file with the following content:

\`\`\`javascript
new Vue({
    el: '#app',
    data: {
        items: [],
        newItem: ''
    },
    methods: {
        addItem() {
            if (this.newItem.trim()) {
                this.items.push(this.newItem);
                this.newItem = '';
            }
        }
    }
});
\`\`\`

Then run: \`node app.js\`"

parse_test_response "$test_response"

echo -e "\nTest complete!"