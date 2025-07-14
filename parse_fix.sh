#!/bin/bash

# Simplified parser fix that focuses on the core issue
# This replaces the parse_ai_response_to_operations function with a more reliable version

cat > /tmp/parse_fix_function.sh << 'EOF'
parse_ai_response_to_operations() {
    local response_text=$1
    local operations_json="[]"
    
    # Save response to temp file for easier processing
    local temp_response=$(mktemp)
    echo "$response_text" > "$temp_response"
    
    # Variables to track context
    local mentioned_filename=""
    
    # First pass: Look for filename mentions before code blocks
    while IFS= read -r line; do
        # Look for filename mentions in backticks (e.g., `hello.js`)
        if [[ "$line" =~ \`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\` ]]; then
            mentioned_filename="${BASH_REMATCH[1]}"
        fi
    done < "$temp_response"
    
    # Extract code blocks with improved pattern matching
    local in_code_block=false
    local current_lang=""
    local current_code=""
    local code_block_started=false
    
    while IFS= read -r line; do
        # Check for code block start (triple backticks)
        if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]*) ]]; then
            if [[ "$in_code_block" == "false" ]]; then
                in_code_block=true
                current_lang="${BASH_REMATCH[1]:-plaintext}"
                current_code=""
                code_block_started=true
            else
                # End of code block - process it
                in_code_block=false
                if [[ -n "$current_code" ]]; then
                    local filename=""
                    
                    # Use mentioned filename if available
                    if [[ -n "$mentioned_filename" ]]; then
                        filename="$mentioned_filename"
                    else
                        # Try to detect filename from code comments
                        local first_line=$(echo "$current_code" | head -1)
                        if [[ "$first_line" =~ ^[[:space:]]*(//|#)[[:space:]]*([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+) ]]; then
                            filename="${BASH_REMATCH[2]}"
                        else
                            # Use default based on language
                            case "$current_lang" in
                                javascript|js) filename="script.js" ;;
                                python|py) filename="script.py" ;;
                                bash|sh) filename="script.sh" ;;
                                json) 
                                    if [[ "$current_code" =~ \"name\".*\"version\" ]]; then
                                        filename="package.json"
                                    else
                                        filename="config.json"
                                    fi
                                    ;;
                                html) filename="index.html" ;;
                                css) filename="styles.css" ;;
                                typescript|ts) filename="script.ts" ;;
                                *) 
                                    if [[ -n "$current_lang" ]]; then
                                        filename="file.$current_lang"
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                    
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
                mentioned_filename=""  # Reset for next code block
            fi
        elif [[ "$in_code_block" == "true" ]]; then
            # Inside code block - accumulate code
            if [[ -n "$current_code" ]]; then
                current_code+=$'\n'
            fi
            current_code+="$line"
        fi
    done < "$temp_response"
    
    # Extract shell commands
    # Look for commands in backticks
    local commands=$(grep -oE '`[^`]+`' "$temp_response" 2>/dev/null | sed 's/`//g' || true)
    
    # Process commands
    while IFS= read -r cmd; do
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
        if [[ -n "$cmd" ]]; then
            # Check if it's a valid command
            if [[ "$cmd" =~ ^(npm|yarn|node|python|pip|git|mkdir|ls|cat|echo|touch|cp|mv|rm|bash|sh) ]]; then
                local op=$(jq -n --arg cmd "$cmd" '{type: "command", command: $cmd}')
                operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
            fi
        fi
    done <<< "$commands"
    
    # Clean up
    rm -f "$temp_response"
    
    # Return operations if any were found
    if [[ $(echo "$operations_json" | jq 'length') -gt 0 ]]; then
        echo "$operations_json"
    fi
}
EOF

# Apply the fix to int.sh
echo "Applying parser fix to int.sh..."

# Create a backup
cp int.sh int.sh.backup

# Find the function in int.sh and replace it
start_line=$(grep -n "^parse_ai_response_to_operations()" int.sh | cut -d: -f1)
if [[ -n "$start_line" ]]; then
    # Find the end of the function
    end_line=$(awk -v start="$start_line" 'NR > start && /^}$/ && --count == 0 {print NR; exit} /^[[:space:]]*{/ {count++} /^[[:space:]]*}/ && NR > start {count--}' int.sh)
    
    if [[ -n "$end_line" ]]; then
        # Create the fixed version
        head -n $((start_line - 1)) int.sh > int_fixed.sh
        cat /tmp/parse_fix_function.sh >> int_fixed.sh
        tail -n +$((end_line + 1)) int.sh >> int_fixed.sh
        
        # Make it executable
        chmod +x int_fixed.sh
        
        echo "✅ Created int_fixed.sh with improved parser"
        echo "   Original backed up to int.sh.backup"
    else
        echo "❌ Could not find function end"
    fi
else
    echo "❌ Could not find parse_ai_response_to_operations function"
fi

# Clean up
rm -f /tmp/parse_fix_function.sh