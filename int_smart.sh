#!/bin/bash

# Smart ThinkAI CLI with Exponentially Enhanced Parsing

# Base URL of the API
BASE_URL="https://thinkai.lat/api"

# Source enhanced modules
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -f "$SCRIPT_DIR/enhanced_functions.sh" ]] && source "$SCRIPT_DIR/enhanced_functions.sh"
[[ -f "$SCRIPT_DIR/enhanced_parser.sh" ]] && source "$SCRIPT_DIR/enhanced_parser.sh"
[[ -f "$SCRIPT_DIR/enhanced_system_prompt.sh" ]] && source "$SCRIPT_DIR/enhanced_system_prompt.sh"

# Directory for storing conversation data
CONV_DIR="$HOME/.cliii/conversations"
CURRENT_CONV_FILE="$HOME/.cliii/current_conversation"
CONTEXT_DIR="$HOME/.cliii/context"

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

# Detect project type
detect_project_type() {
    if [[ -f "package.json" ]]; then
        echo "nodejs"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        echo "python"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        echo "java"
    else
        echo "generic"
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

# Get conversation context
get_conversation_context() {
    local conv_id=$1
    local conv_file="$CONV_DIR/${conv_id}.json"
    
    if [[ -f "$conv_file" ]] && command -v jq &> /dev/null; then
        # Get last 5 messages for context
        jq -r '.messages[-5:] | map(.role + ": " + (.content | split("\n")[0:2] | join(" ") | .[0:100])) | join("\n")' "$conv_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Enhanced send message with context
send_to_thinkai_smart() {
    local message=$1
    local conv_id=$2
    local context="[]"
    
    # Detect project type and get context
    local project_type=$(detect_project_type)
    local conversation_context=$(get_conversation_context "$conv_id")
    local existing_files=$(ls -1 *.{js,py,go,rs,java,cpp,c,sh} 2>/dev/null | head -10 | tr '\n' ' ' || echo "")
    
    # Generate enhanced system prompt
    local base_prompt=$(generate_enhanced_system_prompt 2>/dev/null || echo "You are an AI coding assistant.")
    local context_prompt=$(generate_context_prompt "$project_type" "$existing_files" "" 2>/dev/null || echo "")
    local full_system_prompt="$base_prompt\n\n$context_prompt"
    
    # Detect task type from message
    local task_prompt=""
    if [[ "$message" =~ (debug|fix|error) ]]; then
        task_prompt=$(generate_task_prompt "debug" 2>/dev/null || echo "")
    elif [[ "$message" =~ (refactor|improve|clean) ]]; then
        task_prompt=$(generate_task_prompt "refactor" 2>/dev/null || echo "")
    elif [[ "$message" =~ (test|spec) ]]; then
        task_prompt=$(generate_task_prompt "test" 2>/dev/null || echo "")
    elif [[ "$message" =~ (optimize|performance|faster) ]]; then
        task_prompt=$(generate_task_prompt "optimize" 2>/dev/null || echo "")
    fi
    
    [[ -n "$task_prompt" ]] && full_system_prompt+="\n\n$task_prompt"
    
    # Add conversation context
    if [[ -n "$conversation_context" ]]; then
        context=$(echo "$conversation_context" | jq -Rs '[.]')
    fi
    
    # Escape for JSON
    local escaped_message=$(echo "$message" | jq -Rs .)
    local escaped_system=$(echo "$full_system_prompt" | jq -Rs .)
    
    # Send request
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

# Stream text with progress indicator
stream_text_with_progress() {
    local text=$1
    local color=${2:-"\033[1;36m"}
    local reset="\033[0m"
    
    echo -ne "$color"
    while IFS= read -r -n1 char; do
        echo -n "$char"
        sleep 0.003 2>/dev/null || true
    done <<< "$text"
    echo -e "$reset"
}

# Parse response using smart parser
parse_response_smart() {
    local response_text=$1
    local conv_id=$2
    
    if type -t parse_progressive &>/dev/null; then
        parse_progressive "$response_text" "$conv_id"
    elif type -t extract_operations_smart &>/dev/null; then
        extract_operations_smart "$response_text"
    else
        # Fallback to original parser
        parse_ai_response_to_operations "$response_text"
    fi
}

# Execute operations with validation
execute_operations_smart() {
    local operations=$1
    local conv_id=$2
    
    local num_ops=$(echo "$operations" | jq 'length' 2>/dev/null || echo 0)
    if [[ $num_ops -eq 0 ]]; then
        return 0
    fi
    
    echo -e "\n\033[1;36m🚀 Executing $num_ops smart operations...\033[0m"
    
    # Process each operation
    echo "$operations" | jq -c '.[]' | while IFS= read -r op; do
        local op_type=$(echo "$op" | jq -r '.type')
        
        case "$op_type" in
            "file")
                local operation=$(echo "$op" | jq -r '.operation')
                local file_path=$(echo "$op" | jq -r '.path')
                local content=$(echo "$op" | jq -r '.content')
                
                echo -e "\033[1;34m📄 $operation: $file_path\033[0m"
                handle_file_operations "$operation" "$content" "$file_path"
                ;;
            "command")
                local cmd=$(echo "$op" | jq -r '.command')
                
                # Validate command with smart validator if available
                if type -t validate_command_smart &>/dev/null; then
                    if validate_command_smart "$cmd"; then
                        execute_command_safe "$cmd"
                    else
                        echo -e "\033[1;31m⚠️  Skipping unsafe command: $cmd\033[0m"
                    fi
                else
                    execute_command_safe "$cmd"
                fi
                ;;
            "context")
                # Handle context operations
                echo -e "\033[1;90m📋 Building on previous work...\033[0m"
                ;;
        esac
    done
}

# Original parsing function (fallback)
parse_ai_response_to_operations() {
    local response_text=$1
    local operations_json="[]"
    local temp_response=$(mktemp)
    echo "$response_text" > "$temp_response"
    
    local in_code_block=false
    local current_lang=""
    local current_code=""
    local current_filename=""
    local last_mentioned_file=""
    
    while IFS= read -r line; do
        # Check for filename mentions
        if [[ "$line" =~ (Create|create|Edit|edit|Update|update|Save|save)[[:space:]]+(an?[[:space:]]+)?\`?([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`? ]] || 
           [[ "$line" =~ \`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\`[[:space:]]*(file|with) ]] ||
           [[ "$line" =~ (file|File)[[:space:]]+\`([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)\` ]] ||
           [[ "$line" =~ ^###[[:space:]]+([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+) ]] ||
           [[ "$line" =~ ([a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+):?$ ]]; then
            last_mentioned_file="${BASH_REMATCH[3]:-${BASH_REMATCH[1]:-${BASH_REMATCH[2]}}}"
        fi
        
        # Check for code block markers
        if [[ "$line" =~ ^\`\`\` ]]; then
            if [[ "$in_code_block" == "false" ]] || [[ -z "$in_code_block" ]]; then
                in_code_block=true
                if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]+) ]]; then
                    current_lang="${BASH_REMATCH[1]}"
                else
                    current_lang="plaintext"
                fi
                current_code=""
                current_filename="$last_mentioned_file"
            else
                in_code_block=false
                if [[ -n "$current_code" ]]; then
                    local filename="$current_filename"
                    
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
    
    # Extract commands
    while IFS= read -r line; do
        if [[ "$line" =~ (run|execute|Run|Execute):[[:space:]]*\`([^\`]+)\` ]] ||
           [[ "$line" =~ (command|Command):[[:space:]]*\`([^\`]+)\` ]] ||
           [[ "$line" =~ ^[[:space:]]*\$[[:space:]]+(.*) ]] ||
           [[ "$line" =~ \`(npm[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(node[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(python[[:space:]]+[^\`]+)\` ]] ||
           [[ "$line" =~ \`(git[[:space:]]+[^\`]+)\` ]]; then
            
            local cmd="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
            cmd=$(echo "$cmd" | xargs)
            
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
    
    if [[ "$command" =~ ^(node|python|python3|ruby|perl|php|bash|sh)$ ]]; then
        echo -e "\033[1;33m⚠ Skipping bare interpreter: $command\033[0m"
        return 0
    fi
    
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

# Show help
show_help() {
    cat << EOF

🚀 Smart ThinkAI CLI Commands:
  exit  - Exit the CLI
  help  - Show this help message
  
💡 Smart Parsing Features:
  - Advanced regex patterns for code detection
  - Context-aware response parsing
  - Progressive coding with memory
  - Intelligent command validation
  - Auto-detection of project dependencies
  
📝 Examples:
  "create an express server"
  "add user authentication"
  "debug the error in line 42"
  "refactor for better performance"

EOF
}

# Main loop
echo -e "\033[1;35m🚀 Welcome to Smart ThinkAI CLI!\033[0m"
echo -e "\033[1;36mType 'exit' to quit, 'help' for commands\033[0m"

# Initialize
init_conversation_storage
current_conversation=$(load_current_conversation)
echo -e "\033[1;32m💬 Conversation: $current_conversation\033[0m"

# Detect project type
project_type=$(detect_project_type)
[[ "$project_type" != "generic" ]] && echo -e "\033[1;32m📦 Project type: $project_type\033[0m"

AGENTIC_MODE="${CLIII_AGENTIC_MODE:-true}"
[[ "$AGENTIC_MODE" == "true" ]] && echo -e "\033[1;32m🤖 Smart parsing enabled\033[0m"

while true; do
    read -r -p "> " user_input
    
    case "$user_input" in
        "exit")
            echo -e "\033[1;34m👋 Goodbye!\033[0m"
            break
            ;;
        "help")
            show_help
            continue
            ;;
        "")
            continue
            ;;
    esac
    
    # Save user message
    save_to_conversation "$current_conversation" "user" "$user_input"
    
    # Get AI response
    echo -ne "\033[1;36m🤔 Thinking...\033[0m"
    response=$(send_to_thinkai_smart "$user_input" "$current_conversation")
    echo -ne "\r\033[K"
    
    # Extract response text
    response_text=$(echo "$response" | jq -r '.response // .message // .' 2>/dev/null || echo "$response")
    
    # Save and stream response
    save_to_conversation "$current_conversation" "assistant" "$response_text"
    stream_text_with_progress "$response_text"
    
    # Parse and execute operations if agentic mode is enabled
    if [[ "$AGENTIC_MODE" == "true" ]]; then
        operations=$(parse_response_smart "$response_text" "$current_conversation")
        if [[ -n "$operations" ]]; then
            execute_operations_smart "$operations" "$current_conversation"
        fi
    fi
done