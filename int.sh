#!/bin/bash

# Base URL of the API
BASE_URL="https://thinkai.lat/api"

# Directory for storing conversation data
CONV_DIR="$HOME/.cliii/conversations"
CURRENT_CONV_FILE="$HOME/.cliii/current_conversation"

# Initialize conversation directory
init_conversation_storage() {
    mkdir -p "$CONV_DIR"
    mkdir -p "$(dirname "$CURRENT_CONV_FILE")"
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
    
    # Create or append to conversation file
    if [[ ! -f "$conv_file" ]]; then
        echo '{"conversation_id":"'"$conv_id"'","messages":[]}' > "$conv_file"
    fi
    
    # Add message to conversation
    local temp_file="${conv_file}.tmp"
    if command -v jq &> /dev/null; then
        jq --arg role "$role" --arg content "$message" --arg ts "$timestamp" \
            '.messages += [{"role": $role, "content": $content, "timestamp": $ts}]' \
            "$conv_file" > "$temp_file" && mv "$temp_file" "$conv_file"
    else
        # Fallback: append to file manually (basic JSON handling)
        echo "Warning: jq not found. Using basic append method." >&2
        # This is a simplified fallback - in production, install jq
    fi
}

# Get conversation history
get_conversation_history() {
    local conv_id=$1
    local conv_file="$CONV_DIR/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        if command -v jq &> /dev/null; then
            jq -r '.messages[] | "[\(.role)]: \(.content)"' "$conv_file"
        else
            echo "Warning: jq not found. Cannot display history." >&2
        fi
    fi
}

# Function to send a message to ThinkAI and get a response
send_to_thinkai() {
    local message=$1
    local conv_id=$2
    local context=""
    
    # Get recent conversation history (last 10 messages for context)
    if [[ -n "$conv_id" ]] && [[ -f "$CONV_DIR/${conv_id}.json" ]]; then
        if command -v jq &> /dev/null; then
            context=$(jq -r '.messages[-10:] | map({"role": .role, "content": .content}) | @json' "$CONV_DIR/${conv_id}.json" 2>/dev/null || echo "[]")
        else
            context="[]"
        fi
    else
        context="[]"
    fi
    
    local response
    response=$(curl -s -X POST "${BASE_URL}/chat" \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"$message\",\"conversation_id\":\"$conv_id\",\"context\":$context}")
    echo "$response"
}

# Function to display text with color
display_colored_text() {
    local text=$1
    # Using ANSI escape codes for colors
    echo -e "\033[1;36m$text\033[0m" | sed 's/"/\n/g' | sed "s/{/\n/g" | sed "s/}/\n/g" | sed "s/,/\n/g" | sed "s/response://g" | sed "s/ThinkAI://g"
}

# Function to display a simple animation
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

# Function to handle file operations
handle_file_operations() {
    local operation=$1
    local file_content=$2
    local file_name=$3

    if [[ "$operation" == "write" ]]; then
        echo "$file_content" > "$file_name"
        echo -e "\033[1;32mFile $file_name has been written.\033[0m"
    else
        echo -e "\033[1;31mUnknown file operation: $operation\033[0m"
    fi
}

# Function to execute a command locally
execute_command() {
    local command=$1
    echo -e "\033[1;33mExecuting command: $command\033[0m"
    eval "$command"
}

# List all conversations
list_conversations() {
    echo -e "\033[1;36mAvailable conversations:\033[0m"
    if [[ -d "$CONV_DIR" ]]; then
        for conv_file in "$CONV_DIR"/*.json; do
            if [[ -f "$conv_file" ]]; then
                local conv_id=$(basename "$conv_file" .json)
                local msg_count=$(jq '.messages | length' "$conv_file" 2>/dev/null || echo "?")
                local last_msg=$(jq -r '.messages[-1].timestamp // "No messages"' "$conv_file" 2>/dev/null || echo "Unknown")
                echo -e "  \033[1;33m$conv_id\033[0m - Messages: $msg_count, Last: $last_msg"
            fi
        done
    else
        echo "  No conversations found."
    fi
}

# Switch to a different conversation
switch_conversation() {
    local conv_id=$1
    if [[ -f "$CONV_DIR/${conv_id}.json" ]]; then
        echo "$conv_id" > "$CURRENT_CONV_FILE"
        echo -e "\033[1;32mSwitched to conversation: $conv_id\033[0m"
        return 0
    else
        echo -e "\033[1;31mConversation not found: $conv_id\033[0m"
        return 1
    fi
}

# Create a new conversation
new_conversation() {
    local new_id=$(generate_conversation_id)
    echo "$new_id" > "$CURRENT_CONV_FILE"
    echo -e "\033[1;32mCreated new conversation: $new_id\033[0m"
}

# Show conversation history
show_history() {
    local conv_id=$1
    if [[ -z "$conv_id" ]]; then
        conv_id=$(load_current_conversation)
    fi
    
    echo -e "\033[1;36mConversation history for: $conv_id\033[0m"
    if [[ -f "$CONV_DIR/${conv_id}.json" ]]; then
        if command -v jq &> /dev/null; then
            jq -r '.messages[] | "\(.timestamp) [\(.role)]: \(.content)"' "$CONV_DIR/${conv_id}.json"
        else
            echo "Warning: jq not found. Cannot display detailed history."
        fi
    else
        echo "No history found."
    fi
}

# Main interactive loop
echo -e "\033[1;35mWelcome to ThinkAI CLI with conversation persistence!\033[0m"
echo -e "\033[1;36mCommands: /new, /list, /switch <id>, /history, /clear, exit\033[0m"

# Initialize storage and load current conversation
init_conversation_storage
current_conversation=$(load_current_conversation)
echo -e "\033[1;32mCurrent conversation: $current_conversation\033[0m"

while true; do
    read -r -p "> " user_input

    # Handle special commands
    case "$user_input" in
        "exit")
            echo -e "\033[1;34mGoodbye!\033[0m"
            break
            ;;
        "/new")
            new_conversation
            current_conversation=$(load_current_conversation)
            continue
            ;;
        "/list")
            list_conversations
            continue
            ;;
        "/switch "*)
            conv_id="${user_input#/switch }"
            if switch_conversation "$conv_id"; then
                current_conversation="$conv_id"
            fi
            continue
            ;;
        "/history")
            show_history "$current_conversation"
            continue
            ;;
        "/clear")
            clear
            echo -e "\033[1;35mThinkAI CLI - Conversation: $current_conversation\033[0m"
            continue
            ;;
        "")
            continue
            ;;
    esac

    # Save user message to conversation
    save_to_conversation "$current_conversation" "user" "$user_input"

    # Display animation while waiting for response
    display_animation &

    # Send user input to ThinkAI and get response with context
    response=$(send_to_thinkai "$user_input" "$current_conversation")

    # Kill the animation process
    kill $!; wait $! 2>/dev/null
    echo -ne "\r"

    # Extract just the response text (assuming JSON response)
    if command -v jq &> /dev/null; then
        response_text=$(echo "$response" | jq -r '.response // .message // .' 2>/dev/null || echo "$response")
    else
        response_text="$response"
    fi
    
    # Save assistant response to conversation
    save_to_conversation "$current_conversation" "assistant" "$response_text"

    # Display the response with color
    display_colored_text "$response_text"

    # Parse the response (this is a simplified example)
    if [[ "$response" == *"execute"* ]]; then
        command=$(echo "$response" | grep -oP '(?<="command": ")[^"]+')
        execute_command "$command"
    fi
    
    if [[ "$response" == *"file_operation"* ]]; then
        operation=$(echo "$response" | grep -oP '(?<="operation": ")[^"]+')
        file_content=$(echo "$response" | grep -oP '(?<="content": ")[^"]+')
        file_name=$(echo "$response" | grep -oP '(?<="file_name": ")[^"]+')
        handle_file_operations "$operation" "$file_content" "$file_name"
    fi
done

