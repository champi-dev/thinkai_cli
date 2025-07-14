#!/bin/bash

# Comprehensive parser debug script

# Load the actual parsing function from int.sh
parse_ai_response_to_operations() {
    local response_text=$1
    local operations_json="[]"
    
    # Save response to temp file
    local temp_response=$(mktemp)
    echo "$response_text" > "$temp_response"
    
    # Track code blocks and their associated files
    local in_code_block=false
    local current_lang=""
    local current_code=""
    local current_filename=""
    local last_mentioned_file=""
    
    echo "[DEBUG] Starting parse..." >&2
    
    # Process line by line
    while IFS= read -r line; do
        # Check for filename mentions before code blocks
        if [[ "$line" =~ (Create|create|Edit|edit|Update|update|Save|save)[[:space:]]+(an?[[:space:]]+)?\`?([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`? ]] || 
           [[ "$line" =~ \`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`[[:space:]]*(file|with) ]] ||
           [[ "$line" =~ (file|File)[[:space:]]+\`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\` ]] ||
           [[ "$line" =~ ^###[[:space:]]+([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+) ]] ||
           [[ "$line" =~ ([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+):?$ ]] ||
           [[ "$line" =~ //[[:space:]]*([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+) ]]; then
            last_mentioned_file="${BASH_REMATCH[3]:-${BASH_REMATCH[1]:-${BASH_REMATCH[2]}}}"
            echo "[DEBUG] Found filename: $last_mentioned_file" >&2
        fi
        
        # Check for start of code block
        if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]*) ]]; then
            echo "[DEBUG] Found code block start: $line" >&2
            if [[ "$in_code_block" == "false" ]] || [[ -z "$in_code_block" ]]; then
                in_code_block=true
                current_lang="${BASH_REMATCH[1]:-plaintext}"
                current_code=""
                current_filename="$last_mentioned_file"
                echo "[DEBUG] Starting code block - lang: $current_lang, filename: $current_filename" >&2
            fi
        elif [[ "$line" =~ ^\`\`\`$ ]] && [[ "$in_code_block" == "true" ]]; then
            # End of code block
            echo "[DEBUG] Found code block end" >&2
            in_code_block=false
            if [[ -n "$current_code" ]]; then
                local filename="$current_filename"
                
                # If no filename was mentioned, use default based on language
                if [[ -z "$filename" ]]; then
                    case "$current_lang" in
                        javascript|js) filename="app.js" ;;
                        python|py) filename="app.py" ;;
                        bash|sh) filename="script.sh" ;;
                        json) filename="data.json" ;;
                        html) filename="index.html" ;;
                        css) filename="styles.css" ;;
                        *) filename="file.txt" ;;
                    esac
                fi
                
                echo "[DEBUG] Creating file operation for: $filename" >&2
                echo "[DEBUG] Code content (first 50 chars): ${current_code:0:50}" >&2
                
                # Create file write operation
                local escaped_content=$(echo "$current_code" | jq -Rs .)
                local op=$(jq -n --arg path "$filename" --argjson content "$escaped_content" \
                    '{type: "file", operation: "write", path: $path, content: $content}')
                operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
                echo "[DEBUG] Operations JSON now: $operations_json" >&2
            fi
            current_code=""
            current_filename=""
        elif [[ "$in_code_block" == "true" ]]; then
            if [[ -n "$current_code" ]]; then
                current_code+=$'\n'
            fi
            current_code+="$line"
        fi
    done < "$temp_response"
    
    rm -f "$temp_response"
    
    echo "[DEBUG] Final operations count: $(echo "$operations_json" | jq 'length')" >&2
    
    if [[ $(echo "$operations_json" | jq 'length') -gt 0 ]]; then
        echo "$operations_json"
    fi
}

# Test case 1: hello.js example
test_response1='Certainly! Below is a simple `hello.js` file:

```javascript
// hello.js
console.log("Hello from ThinkAI");
```

Save this file and run it with Node.js.'

echo "=== Test Case 1: hello.js ==="
result1=$(parse_ai_response_to_operations "$test_response1" 2>&1)
echo "$result1" | grep -v "^\[DEBUG\]"
echo ""

# Test case 2: Without filename comment
test_response2='Here is the code:

```javascript
console.log("Hello World");
```'

echo "=== Test Case 2: No filename ==="
result2=$(parse_ai_response_to_operations "$test_response2" 2>&1)
echo "$result2" | grep -v "^\[DEBUG\]"
echo ""

# Show debug output
echo "=== Debug Output for Test 1 ==="
echo "$result1" | grep "^\[DEBUG\]"