#!/bin/bash

# CLIII - Command Line Interface for ThinkAI
# Think of this as a smart terminal that remembers your conversations
# and can execute commands and manage files based on AI responses

# Base URL of the API - This is where we send your messages to get AI responses
BASE_URL="https://thinkai.lat/api"

# Directory for storing conversation data
# Like a diary that never forgets - all your chats are saved here
CONV_DIR="$HOME/.cliii/conversations"
# This file tells us which conversation you're currently having
CURRENT_CONV_FILE="$HOME/.cliii/current_conversation"

# Initialize conversation directory
# Like setting up folders for a filing cabinet before you start filing
init_conversation_storage() {
    mkdir -p "$CONV_DIR"                        # Create conversations folder
    mkdir -p "$(dirname "$CURRENT_CONV_FILE")"  # Create .cliii folder
}

# Generate a new conversation ID
# Like creating a unique name tag for each conversation
# Format: conv_YYYYMMDD_HHMMSS_ProcessID (so it's always unique)
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
# Like writing in a diary - who said what and when
# This is crucial for maintaining context across sessions
save_to_conversation() {
    local conv_id=$1      # Which conversation notebook to write in
    local role=$2         # Who's talking: "user" (you) or "assistant" (AI)
    local message=$3      # What was said
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")  # When it was said
    
    local conv_file="$CONV_DIR/${conv_id}.json"
    
    # Create or append to conversation file
    # If this is a new conversation, create a new JSON file with empty messages
    if [[ ! -f "$conv_file" ]]; then
        echo '{"conversation_id":"'"$conv_id"'","messages":[]}' > "$conv_file"
    fi
    
    # Add message to conversation
    # We use a temporary file to avoid corrupting the JSON if something goes wrong
    local temp_file="${conv_file}.tmp"
    if command -v jq &> /dev/null; then
        # jq is like a Swiss Army knife for JSON - it safely adds our message
        # --arg creates variables that are properly escaped (no broken JSON!)
        jq --arg role "$role" --arg content "$message" --arg ts "$timestamp" \
            '.messages += [{"role": $role, "content": $content, "timestamp": $ts}]' \
            "$conv_file" > "$temp_file" && mv "$temp_file" "$conv_file"
    else
        # Without jq, we can't safely modify JSON (risky with special characters)
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
# This is the heart of CLIII - it sends your message along with conversation
# history to the AI and gets back a response that might include commands to run
send_to_thinkai() {
    local message=$1      # Your message to the AI
    local conv_id=$2      # Which conversation this belongs to
    local context=""      # Previous messages for context (like reminding the AI what you talked about)
    
    # Get recent conversation history (last 10 messages for context)
    # Like showing the AI the last page of your conversation so it remembers what you were talking about
    # We limit to 10 messages to keep the API request size reasonable
    if [[ -n "$conv_id" ]] && [[ -f "$CONV_DIR/${conv_id}.json" ]]; then
        if command -v jq &> /dev/null; then
            # Extract last 10 messages and format them for the API
            context=$(jq -r '.messages[-10:] | map({"role": .role, "content": .content}) | @json' "$CONV_DIR/${conv_id}.json" 2>/dev/null || echo "[]")
        else
            context="[]"  # No context if jq isn't installed
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
# Makes the AI's responses pretty and readable in the terminal
display_colored_text() {
    local text=$1
    # \033[1;36m = bright cyan color, \033[0m = reset to normal
    # The sed commands break up JSON-like text to make it more readable
    # Think of it as pretty-printing for humans instead of machines
    echo -e "\033[1;36m$text\033[0m" | sed 's/"/\n/g' | sed "s/{/\n/g" | sed "s/}/\n/g" | sed "s/,/\n/g" | sed "s/response://g" | sed "s/ThinkAI://g"
}

# Function to display a simple animation
# Shows a spinning character while waiting for the AI response
# Like a loading spinner that says "I'm thinking..."
display_animation() {
    local frames=("|" "/" "-" "\\")  # The spinner characters
    for i in {1..10}; do              # Spin 10 times
        for frame in "${frames[@]}"; do
            echo -ne "\r$frame"       # \r returns cursor to start of line
            sleep 0.1                 # Wait 100ms between frames
        done
    done
    echo -ne "\r"                    # Clear the spinner
}

# Function to handle file operations
# When the AI wants to create, edit, or delete files, this function does the actual work
# Like being the AI's hands in your file system
handle_file_operations() {
    local operation=$1    # What to do: write, edit, append, delete, mkdir, read
    local content=$2      # What to write/append (if applicable)
    local file_path=$3    # Where to do it
    local old_content=$4  # What to replace (for edit operations)

    case "$operation" in
        "write")
            # Create any parent directories needed (like mkdir -p does)
            # dirname gets the directory part of the path
            mkdir -p "$(dirname "$file_path")"
            # Write content to file (> overwrites existing content)
            echo -e "$content" > "$file_path"
            # Green checkmark with success message
            echo -e "\033[1;32m✓ File $file_path has been written\033[0m"
            ;;
        "edit")
            if [[ -f "$file_path" ]]; then
                # Two ways to edit:
                if [[ -n "$old_content" ]]; then
                    # 1. Find and replace specific content
                    # sed -i modifies file in-place, s|old|new|g replaces all occurrences
                    sed -i "s|$old_content|$content|g" "$file_path"
                    echo -e "\033[1;32m✓ Edited file: $file_path\033[0m"
                else
                    # 2. Replace entire file content
                    echo -e "$content" > "$file_path"
                    echo -e "\033[1;32m✓ Replaced content in: $file_path\033[0m"
                fi
            else
                # Red X for errors
                echo -e "\033[1;31m✗ File not found: $file_path\033[0m"
            fi
            ;;
        "append")
            mkdir -p "$(dirname "$file_path")"
            echo -e "$content" >> "$file_path"
            echo -e "\033[1;32m✓ Appended to file: $file_path\033[0m"
            ;;
        "delete")
            if [[ -f "$file_path" ]]; then
                rm "$file_path"
                echo -e "\033[1;32m✓ Deleted file: $file_path\033[0m"
            else
                echo -e "\033[1;31m✗ File not found: $file_path\033[0m"
            fi
            ;;
        "mkdir")
            mkdir -p "$file_path"
            echo -e "\033[1;32m✓ Created directory: $file_path\033[0m"
            ;;
        "read")
            if [[ -f "$file_path" ]]; then
                echo -e "\033[1;36m--- Content of $file_path ---\033[0m"
                cat "$file_path"
                echo -e "\033[1;36m--- End of file ---\033[0m"
            else
                echo -e "\033[1;31m✗ File not found: $file_path\033[0m"
            fi
            ;;
        *)
            echo -e "\033[1;31m✗ Unknown file operation: $operation\033[0m"
            ;;
    esac
}

# Function to execute a command locally
# When the AI wants to run commands (like 'npm install' or 'mkdir project')
# This function is like giving the AI temporary control of your terminal
execute_command() {
    local command=$1      # The command to run (e.g., "ls -la")
    local working_dir=$2  # Where to run it from (optional)
    
    echo -e "\033[1;33mExecuting command: $command\033[0m"
    
    # Change to working directory if specified
    if [[ -n "$working_dir" ]]; then
        pushd "$working_dir" > /dev/null 2>&1
    fi
    
    # Execute command and capture output/error
    local output
    local exit_code
    # eval runs the command string as if you typed it
    # 2>&1 captures both normal output and errors
    output=$(eval "$command" 2>&1)
    exit_code=$?  # $? stores the exit code of the last command (0 = success)
    
    # Display output
    if [[ -n "$output" ]]; then
        echo "$output"
    fi
    
    # Show status
    if [[ $exit_code -eq 0 ]]; then
        echo -e "\033[1;32m✓ Command executed successfully\033[0m"
    else
        echo -e "\033[1;31m✗ Command failed with exit code: $exit_code\033[0m"
    fi
    
    # Return to original directory
    if [[ -n "$working_dir" ]]; then
        popd > /dev/null 2>&1
    fi
    
    return $exit_code
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
# This is where the magic happens - an infinite loop that:
# 1. Waits for your input
# 2. Sends it to the AI
# 3. Shows the response
# 4. Executes any commands or file operations the AI suggests
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

    # Parse response for operations (enhanced parsing)
    # The AI can respond with text AND instructions to run commands or manage files
    # This section figures out what the AI wants us to do
    if command -v jq &> /dev/null; then
        # Check for legacy execute format
        # Some API responses use {"execute": true, "command": "ls"} format
        if [[ $(echo "$response" | jq -r '.execute // false' 2>/dev/null) == "true" ]]; then
            # Extract the command field, or empty if not found
            cmd=$(echo "$response" | jq -r '.command // empty' 2>/dev/null)
            if [[ -n "$cmd" ]]; then  # -n checks if string is not empty
                execute_command "$cmd"
            fi
        fi
        
        # Check for legacy file_operation format
        if [[ $(echo "$response" | jq -r '.file_operation // false' 2>/dev/null) == "true" ]]; then
            operation=$(echo "$response" | jq -r '.operation // empty' 2>/dev/null)
            file_path=$(echo "$response" | jq -r '.file_name // empty' 2>/dev/null)
            content=$(echo "$response" | jq -r '.content // empty' 2>/dev/null)
            if [[ -n "$operation" && -n "$file_path" ]]; then
                handle_file_operations "$operation" "$content" "$file_path"
            fi
        fi
        
        # Check if response contains operations
        # Modern format: {"operations": [{"type": "file", ...}, {"type": "command", ...}]}
        has_operations=$(echo "$response" | jq -r '.operations // empty' 2>/dev/null)
        
        if [[ -n "$has_operations" ]]; then
            # Count how many operations we need to perform
            num_ops=$(echo "$response" | jq '.operations | length' 2>/dev/null || echo 0)
            
            # Loop through each operation in the array
            for ((i=0; i<num_ops; i++)); do
                # Get the type of this operation (file or command)
                op_type=$(echo "$response" | jq -r ".operations[$i].type" 2>/dev/null)
                
                # Handle each type of operation differently
                case "$op_type" in
                    "file")
                        operation=$(echo "$response" | jq -r ".operations[$i].operation" 2>/dev/null)
                        file_path=$(echo "$response" | jq -r ".operations[$i].path" 2>/dev/null)
                        content=$(echo "$response" | jq -r ".operations[$i].content // empty" 2>/dev/null)
                        old_content=$(echo "$response" | jq -r ".operations[$i].old_content // empty" 2>/dev/null)
                        handle_file_operations "$operation" "$content" "$file_path" "$old_content"
                        ;;
                    "command")
                        cmd=$(echo "$response" | jq -r ".operations[$i].command" 2>/dev/null)
                        working_dir=$(echo "$response" | jq -r ".operations[$i].working_dir // empty" 2>/dev/null)
                        execute_command "$cmd" "$working_dir"
                        ;;
                    *)
                        echo -e "\033[1;33m⚠ Unknown operation type: $op_type\033[0m"
                        ;;
                esac
            done
        fi
    else
        # Fallback: Simple pattern matching for backwards compatibility
        # If jq isn't installed, we try basic string matching (less reliable)
        if [[ "$response" == *"execute"* ]]; then
            # grep -oP uses Perl regex to find text after '"command": "'
            # The || true prevents the script from exiting if grep finds nothing
            cmd=$(echo "$response" | grep -oP '(?<="command": ")[^"]+' || true)
            if [[ -n "$cmd" ]]; then
                execute_command "$cmd"
            fi
        fi
        
        if [[ "$response" == *"file_operation"* ]]; then
            operation=$(echo "$response" | grep -oP '(?<="operation": ")[^"]+' || true)
            file_path=$(echo "$response" | grep -oP '(?<="file_name": ")[^"]+' || true)
            content=$(echo "$response" | grep -oP '(?<="content": ")[^"]+' || true)
            if [[ -n "$operation" && -n "$file_path" ]]; then
                handle_file_operations "$operation" "$content" "$file_path"
            fi
        fi
    fi
done

