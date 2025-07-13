#!/bin/bash

# Base URL of the API
BASE_URL="https://thinkai.lat/api"

# Function to send a message to ThinkAI and get a response
send_to_thinkai() {
    local message=$1
    local response
    response=$(curl -s -X POST "${BASE_URL}/chat" \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"$message\"}")
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

# Main interactive loop
echo -e "\033[1;35mWelcome to ThinkAI CLI. You can start chatting now. Type 'exit' to quit.\033[0m"

while true; do
    read -r -p "> " user_input

    if [[ "$user_input" == "exit" ]]; then
        echo -e "\033[1;34mGoodbye!\033[0m"
        break
    fi

    # Display animation while waiting for response
    display_animation &

    # Send user input to ThinkAI and get response
    response=$(send_to_thinkai "$user_input")

    # Kill the animation process
    kill $!; wait $! 2>/dev/null
    echo -ne "\r"

    # Display the response with color
    display_colored_text "$response"

    # Parse the response (this is a simplified example)
    if [[ "$response" == *"execute"* ]]; then
        command=$(echo "$response" | grep -oP '(?<="command": ")[^"]+')
        execute_command "$command"
    elif [[ "$response" == *"file_operation"* ]]; then
        operation=$(echo "$response" | grep -oP '(?<="operation": ")[^"]+')
        file_content=$(echo "$response" | grep -oP '(?<="content": ")[^"]+')
        file_name=$(echo "$response" | grep -oP '(?<="file_name": ")[^"]+')
        handle_file_operations "$operation" "$file_content" "$file_name"
    fi
done

