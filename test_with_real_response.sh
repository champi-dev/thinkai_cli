#!/bin/bash

# Test parser with the actual API response

# Source the parser function
source <(sed -n '/^parse_ai_response_to_operations()/,/^}/p' ./int.sh)

# Load the actual response text
if [[ -f response_text.txt ]]; then
    response_text=$(cat response_text.txt)
else
    echo "Error: response_text.txt not found. Run capture_real_response.sh first."
    exit 1
fi

echo "=== Testing Parser with Real API Response ==="
echo ""

# Parse the response
operations=$(parse_ai_response_to_operations "$response_text")

if [[ -n "$operations" ]]; then
    echo "✅ Parser found operations:"
    echo "$operations" | jq '.'
    
    # Now actually execute the operations
    echo ""
    echo "=== Executing Operations ==="
    
    # Process each operation
    echo "$operations" | jq -c '.[]' | while read -r op; do
        op_type=$(echo "$op" | jq -r '.type')
        
        case "$op_type" in
            "file")
                path=$(echo "$op" | jq -r '.path')
                content=$(echo "$op" | jq -r '.content')
                echo "Creating file: $path"
                echo "$content" > "$path"
                echo "✅ File created"
                echo "Content:"
                cat "$path"
                ;;
            "command")
                cmd=$(echo "$op" | jq -r '.command')
                echo "Executing command: $cmd"
                eval "$cmd"
                ;;
        esac
        echo ""
    done
else
    echo "❌ No operations found"
fi

echo ""
echo "=== Test Complete ==="
ls -la *.js 2>/dev/null || echo "No JavaScript files created"