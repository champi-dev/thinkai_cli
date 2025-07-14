#!/bin/bash

# CLIII - Command Line Interface for ThinkAI
# Fixed version with working file operations and command execution

# Base URL of the API
BASE_URL="https://thinkai.lat/api"

# Source enhanced functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ -f "$SCRIPT_DIR/enhanced_functions.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_functions.sh"
fi

# Directory for storing conversation data
CONV_DIR="$HOME/.cliii/conversations"
CURRENT_CONV_FILE="$HOME/.cliii/current_conversation"
CONTEXT_DIR="$HOME/.cliii/context"
CODEBASE_INDEX="$HOME/.cliii/context/codebase_index.json"

# Initialize conversation directory
init_conversation_storage() {
    mkdir -p "$CONV_DIR"
    mkdir -p "$(dirname "$CURRENT_CONV_FILE")"
    mkdir -p "$CONTEXT_DIR"
}

# Generate a new conversation ID
generate_conversation_id() {
    echo "conv_$(date +%Y%m%d_%H%M%S)_$$"
}

# Load or create current conversation
load_current_conversation() {
    if [[ -f "$CURRENT_CONV_FILE" ]]; then
        cat "$CURRENT_CONV_FILE"
    else
        local new_id=$(generate_conversation_id)
        echo "$new_id" > "$CURRENT_CONV_FILE"
        echo "$new_id"
    fi
}

# Save message to conversation history
save_to_conversation() {
    local conv_id=$1
    local role=$2
    local message=$3
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local conv_file="$CONV_DIR/${conv_id}.json"
    
    if [[ ! -f "$conv_file" ]]; then
        echo '{"conversation_id":"'"$conv_id"'","messages":[]}' > "$conv_file"
    fi
    
    local temp_file="${conv_file}.tmp"
    if command -v jq &> /dev/null; then
        jq --arg role "$role" --arg content "$message" --arg ts "$timestamp" \
            '.messages += [{"role": $role, "content": $content, "timestamp": $ts}]' \
            "$conv_file" > "$temp_file" && mv "$temp_file" "$conv_file"
    fi
}

# Send message to ThinkAI with better error handling
send_to_thinkai() {
    local message=$1
    local conv_id=$2
    local context="[]"
    
    # System prompt that tells the AI it's a coding assistant
    local system_prompt="You are an AI coding assistant integrated into a command-line interface. You can help users by:
1. Writing code and creating files
2. Executing shell commands
3. Debugging and fixing code
4. Setting up projects and environments

When users ask you to code, create files, or run commands, format your response to include:
- Code blocks with appropriate language tags
- File operations (mention filenames before code blocks like 'Create app.js:' or 'Save as server.js:')
- Shell commands to execute (use format like 'Run: npm install' or '$ npm start')

Be proactive in creating complete, working solutions."
    
    # Escape message and system prompt for JSON
    local escaped_message=$(echo "$message" | jq -Rs .)
    local escaped_system=$(echo "$system_prompt" | jq -Rs .)
    
    local response
    if type -t send_to_ai_with_retry &>/dev/null; then
        response=$(send_to_ai_with_retry "$message" "$conv_id" "$context" "$escaped_system")
    else
        response=$(curl -s -X POST "${BASE_URL}/chat" \
            -H "Content-Type: application/json" \
            -d "{\"message\":$escaped_message,\"conversation_id\":\"$conv_id\",\"context\":$context,\"system_prompt\":$escaped_system}")
    fi
    echo "$response"
}

# Stream text with color character by character
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
        sleep 0.005 2>/dev/null || true
    done <<< "$text"
    echo -e "$reset"
    
    stty echo 2>/dev/null || true
}

# Display animation
display_animation() {
    local frames=("|" "/" "-" "\\")
    for i in {1..10}; do
        for frame in "${frames[@]}"; do
            echo -ne "\r$frame"
            sleep 0.1
        done
    done
    echo -ne "\r"
}

# Handle file operations
handle_file_operations() {
    local operation=$1
    local content=$2
    local file_path=$3
    
    case "$operation" in
        "write")
            mkdir -p "$(dirname "$file_path")"
            echo -e "$content" > "$file_path"
            echo -e "\033[1;32m✓ File $file_path has been written\033[0m"
            ;;
        *)
            echo -e "\033[1;31m✗ Unknown operation: $operation\033[0m"
            ;;
    esac
}

# Execute command safely
execute_command_safe() {
    local command=$1
    
    echo -e "\033[1;33mExecuting command: $command\033[0m"
    
    # Prevent bare interpreters
    if [[ "$command" =~ ^(node|python|python3|ruby|perl|php|bash|sh)$ ]]; then
        echo -e "\033[1;33m⚠ Skipping bare interpreter: $command\033[0m"
        return 0
    fi
    
    # Execute command
    local output
    local exit_code
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    if [[ -n "$output" ]]; then
        echo "$output"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "\033[1;32m✓ Command executed successfully\033[0m"
    else
        echo -e "\033[1;31m✗ Command failed with exit code: $exit_code\033[0m"
    fi
    
    return $exit_code
}

# Parse AI response with better filename detection
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
    
    # Process line by line
    while IFS= read -r line; do
        # Check for filename mentions before code blocks
        if [[ "$line" =~ (Create|create|Edit|edit|Update|update|Save|save)[[:space:]]+(an?[[:space:]]+)?\`?([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`? ]] || 
           [[ "$line" =~ \`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`[[:space:]]*(file|with) ]] ||
           [[ "$line" =~ (file|File)[[:space:]]+\`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\` ]] ||
           [[ "$line" =~ ^###[[:space:]]+([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+) ]] ||
           [[ "$line" =~ ([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+):?$ ]]; then
            last_mentioned_file="${BASH_REMATCH[3]:-${BASH_REMATCH[1]:-${BASH_REMATCH[2]}}}"
        fi
        
        # Check for code block markers
        if [[ "$line" =~ ^\`\`\` ]]; then
            # Check if this is start or end of code block
            if [[ "$in_code_block" == "false" ]] || [[ -z "$in_code_block" ]]; then
                # Starting a code block
                in_code_block=true
                if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]+) ]]; then
                    current_lang="${BASH_REMATCH[1]}"
                else
                    current_lang="plaintext"
                fi
                current_code=""
                current_filename="$last_mentioned_file"
            else
                # Ending a code block
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
                    
                    # Create file write operation
                    local escaped_content=$(echo "$current_code" | jq -Rs .)
                    local op=$(jq -n --arg path "$filename" --argjson content "$escaped_content" \
                        '{type: "file", operation: "write", path: $path, content: $content}')
                    operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
                fi
                current_code=""
                current_filename=""
            fi
        elif [[ "$in_code_block" == "true" ]]; then
            if [[ -n "$current_code" ]]; then
                current_code+=$'\n'
            fi
            current_code+="$line"
        fi
    done < "$temp_response"
    
    # Extract commands - look for common patterns
    while IFS= read -r line; do
        # Match various command patterns
        if [[ "$line" =~ (run|execute|Run|Execute):[[:space:]]*\`([^\`]+)\` ]] ||
           [[ "$line" =~ (command|Command):[[:space:]]*\`([^\`]+)\` ]] ||
           [[ "$line" =~ ^[[:space:]]*\$[[:space:]]+(.*) ]] ||
           [[ "$line" =~ \`(npm[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(node[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(python[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(git[[:space:]]+[^\`]+)\` ]]; then
            
            local cmd="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
            cmd=$(echo "$cmd" | xargs)  # trim whitespace
            
            # Filter out bare interpreters and add to operations
            if [[ -n "$cmd" ]] && [[ ! "$cmd" =~ ^(node|python|python3|ruby|perl|php|bash|sh)$ ]]; then
                local op=$(jq -n --arg cmd "$cmd" '{type: "command", command: $cmd}')
                operations_json=$(echo "$operations_json" | jq --argjson op "$op" '. += [$op]')
            fi
        fi
    done < "$temp_response"
    
    rm -f "$temp_response"
    
    if [[ $(echo "$operations_json" | jq 'length') -gt 0 ]]; then
        echo "$operations_json"
    fi
}

# Main loop
echo -e "\033[1;35mWelcome to ThinkAI CLI (Fixed Version)!\033[0m"
echo -e "\033[1;36mType 'exit' to quit\033[0m"

# Initialize
init_conversation_storage
current_conversation=$(load_current_conversation)
echo -e "\033[1;32mConversation: $current_conversation\033[0m"

AGENTIC_MODE="${CLIII_AGENTIC_MODE:-true}"
if [[ "$AGENTIC_MODE" == "true" ]]; then
    echo -e "\033[1;32m🤖 Agentic mode enabled\033[0m"
fi

while true; do
    read -r -p "> " user_input
    
    case "$user_input" in
        "exit")
            echo -e "\033[1;34mGoodbye!\033[0m"
            break
            ;;
        "")
            continue
            ;;
    esac
    
    # Save user message
    save_to_conversation "$current_conversation" "user" "$user_input"
    
    # Show animation
    display_animation &
    animation_pid=$!
    
    # Get AI response
    response=$(send_to_thinkai "$user_input" "$current_conversation")
    
    # Kill animation
    kill $animation_pid 2>/dev/null || true
    wait $animation_pid 2>/dev/null || true
    echo -ne "\r"
    
    # Extract response text
    if command -v jq &> /dev/null; then
        response_text=$(echo "$response" | jq -r '.response // .message // .' 2>/dev/null || echo "$response")
    else
        response_text="$response"
    fi
    
    # Save and stream response
    save_to_conversation "$current_conversation" "assistant" "$response_text"
    stream_colored_text "$response_text"
    
    # Parse and execute operations if agentic mode is enabled
    if [[ "$AGENTIC_MODE" == "true" ]]; then
        operations=$(parse_ai_response_to_operations "$response_text")
        if [[ -n "$operations" ]]; then
            num_ops=$(echo "$operations" | jq 'length' 2>/dev/null || echo 0)
            if [[ $num_ops -gt 0 ]]; then
                echo -e "\n\033[1;36m🤖 Executing $num_ops operations...\033[0m"
                
                # Execute each operation
                echo "$operations" | jq -c '.[]' | while IFS= read -r op; do
                    op_type=$(echo "$op" | jq -r '.type')
                    
                    case "$op_type" in
                        "file")
                            operation=$(echo "$op" | jq -r '.operation')
                            file_path=$(echo "$op" | jq -r '.path')
                            content=$(echo "$op" | jq -r '.content')
                            handle_file_operations "$operation" "$content" "$file_path"
                            ;;
                        "command")
                            cmd=$(echo "$op" | jq -r '.command')
                            execute_command_safe "$cmd"
                            ;;
                    esac
                done
            fi
        fi
    fi
done