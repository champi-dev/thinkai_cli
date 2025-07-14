#!/bin/bash

# Test script for ThinkAI CLI streaming and smart features

echo -e "\033[1;36m=== ThinkAI CLI Streaming & Smart Features Test ===\033[0m\n"

# Source the enhanced functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/enhanced_functions.sh"

# Test configuration
export CLIII_STREAMING=true
export CLIII_SMART_MODE=true
export DEBUG_MODE=true

# Mock BASE_URL if not set
BASE_URL="${BASE_URL:-https://thinkai.lat/api}"

echo -e "\033[1;34m1. Testing Streaming API Function\033[0m"
echo "Testing with a simple query..."

# Create a test conversation ID
test_conv_id="test_streaming_$(date +%s)"

# Test streaming function (will fallback to regular if streaming not available)
response=$(send_to_ai_streaming "What is 2+2?" "$test_conv_id" "[]" 2>&1)
if [[ $? -eq 0 ]]; then
    echo -e "\033[1;32m✅ Streaming function executed successfully\033[0m"
    echo "Response: $(echo "$response" | jq -r '.response // .' 2>/dev/null | head -n 1)"
else
    echo -e "\033[1;31m❌ Streaming function failed\033[0m"
fi

echo -e "\n\033[1;34m2. Testing Smart Command Suggestions\033[0m"
test_suggestions=(
    "create a new directory called test"
    "show all javascript files"
    "install express package"
    "run the server"
)

for suggestion in "${test_suggestions[@]}"; do
    echo -e "\nInput: '$suggestion'"
    cmd=$(get_smart_suggestions "$suggestion" "[]" "$test_conv_id" 2>/dev/null)
    if [[ -n "$cmd" ]] && [[ "$cmd" != "null" ]]; then
        echo -e "\033[1;32m✅ Suggested: $cmd\033[0m"
    else
        echo -e "\033[1;33m⚠ No suggestion available\033[0m"
    fi
done

echo -e "\n\033[1;34m3. Testing Error Analysis\033[0m"
# Simulate an error
error_output="npm ERR! code ENOENT
npm ERR! syscall open
npm ERR! path /home/user/package.json
npm ERR! errno -2
npm ERR! enoent ENOENT: no such file or directory"

failed_cmd="npm install express"

echo "Analyzing error for command: $failed_cmd"
analyze_error_with_ai "$error_output" "$failed_cmd" "$test_conv_id"

echo -e "\n\033[1;34m4. Testing Progress Indicators\033[0m"
# Create test operations
test_operations='[
    {"type": "file", "operation": "write", "path": "test1.txt", "content": "Hello"},
    {"type": "command", "command": "echo Testing"},
    {"type": "file", "operation": "write", "path": "test2.txt", "content": "World"}
]'

execute_operations_with_progress "$test_operations"

echo -e "\n\033[1;34m5. Testing Command Validation\033[0m"
test_commands=(
    "ls -la"
    "rm -rf /"
    "echo 'Hello World'"
)

for cmd in "${test_commands[@]}"; do
    echo -e "\nValidating: '$cmd'"
    if validate_command_with_ai "$cmd" "$test_conv_id" 2>/dev/null; then
        echo -e "\033[1;32m✅ Command is safe\033[0m"
    else
        echo -e "\033[1;31m❌ Command validation failed or unsafe\033[0m"
    fi
done

echo -e "\n\033[1;34m6. Testing Context-Aware Enhancement\033[0m"
# Create a mock package.json to simulate Node.js project
echo '{"name": "test-project"}' > package.json

test_enhance_cmd="install lodash"
echo "Original command: '$test_enhance_cmd'"
enhanced=$(enhance_command_with_context "$test_enhance_cmd" "$(pwd)" "$test_conv_id" <<< "n")
echo "Enhanced result: $enhanced"

# Cleanup
rm -f package.json test1.txt test2.txt

echo -e "\n\033[1;36m=== Test Complete ===\033[0m"
echo -e "\033[1;90mNote: Some tests may fail if the ThinkAI API is unavailable or doesn't support streaming yet.\033[0m"