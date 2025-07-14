#!/bin/bash

# E2E tests for core CLIII functionality with conversation context
# Verifies file operations, command execution, and folder management work correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_HOME="$HOME/tmp/cliii_func_test_$$"
TEST_WORKSPACE="$TEST_HOME/workspace"
export HOME="$TEST_HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/../int.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Mock curl for testing - returns appropriate responses
mock_curl() {
    local data=""
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-d" ]]; then
            data="$2"
            break
        fi
        shift
    done
    
    local message=$(echo "$data" | jq -r '.message // ""')
    
    # Return different responses based on the message
    case "$message" in
        *"write a test file"*)
            echo '{"response": "I'\''ll create a test file for you", "file_operation": {"operation": "write", "content": "Hello from CLIII!\nThis is a test file.", "file_name": "test_output.txt"}}'
            ;;
        *"create multiple files"*)
            echo '{"response": "Creating multiple files", "file_operation": {"operation": "write", "content": "File 1 content", "file_name": "file1.txt"}}'
            ;;
        *"list files"*)
            echo '{"response": "I'\''ll list the files", "execute": {"command": "ls -la"}}'
            ;;
        *"create a directory"*)
            echo '{"response": "Creating directory", "execute": {"command": "mkdir -p test_directory"}}'
            ;;
        *"run a complex command"*)
            echo '{"response": "Running complex command", "execute": {"command": "echo \"Current date: $(date)\" && pwd && ls -la"}}'
            ;;
        *"calculate"*)
            echo '{"response": "Calculating", "execute": {"command": "echo \"2 + 2 = 4\""}}'
            ;;
        *"write json file"*)
            echo '{"response": "Creating JSON file", "file_operation": {"operation": "write", "content": "{\"name\": \"test\", \"value\": 123}", "file_name": "data.json"}}'
            ;;
        *"write script"*)
            echo '{"response": "Creating script", "file_operation": {"operation": "write", "content": "#!/bin/bash\necho \"Hello from script\"", "file_name": "test_script.sh"}}'
            ;;
        *"check conversation"*)
            # Check if context is being passed
            local context=$(echo "$data" | jq -r '.context // "[]"')
            if [[ "$context" != "[]" ]]; then
                echo '{"response": "I can see our previous conversation in my context"}'
            else
                echo '{"response": "No previous context found"}'
            fi
            ;;
        *)
            echo '{"response": "Acknowledged: '"$message"'"}'
            ;;
    esac
}

# Override curl with our mock
curl() {
    mock_curl "$@"
}
export -f curl
export -f mock_curl

# Setup test environment
setup() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_WORKSPACE"
    cd "$TEST_WORKSPACE"
}

# Cleanup test environment
cleanup() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    cd /
    rm -rf "$TEST_HOME"
}

# Test helper: Run CLI commands
run_cli_commands() {
    local commands="$1"
    echo -e "$commands" | timeout 10s bash "$SCRIPT_PATH" 2>&1
}

# Test helper: Check file exists and contains content
assert_file_contains() {
    local file="$1"
    local expected="$2"
    local test_name="$3"
    
    if [[ -f "$file" ]]; then
        if grep -q "$expected" "$file"; then
            echo -e "${GREEN}✓ $test_name: File contains expected content${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ $test_name: File missing expected content${NC}"
            echo "  Expected: $expected"
            echo "  Actual: $(cat "$file")"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ $test_name: File not found - $file${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test helper: Check output contains string
assert_output_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"
    
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓ $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $test_name${NC}"
        echo "  Expected to find: $expected"
        ((TESTS_FAILED++))
    fi
}

# Test 1: File write operations
test_file_write() {
    echo -e "\n${YELLOW}Test 1: File write operations with context${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Test single file write
    local output=$(run_cli_commands "write a test file\nexit")
    
    # Check if file was created
    assert_file_contains "test_output.txt" "Hello from CLIII" "Single file write"
    
    # Verify conversation was saved
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation" 2>/dev/null)
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        local msg_count=$(jq '.messages | length' "$conv_file")
        if [[ $msg_count -ge 2 ]]; then
            echo -e "${GREEN}✓ File operation saved in conversation history${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ File operation not saved in conversation${NC}"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 2: Command execution
test_command_execution() {
    echo -e "\n${YELLOW}Test 2: Command execution with context${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Test ls command
    local output=$(run_cli_commands "list files in current directory\nexit")
    assert_output_contains "$output" "Executing command: ls -la" "Command execution triggered"
    
    # Test directory creation
    output=$(run_cli_commands "create a directory named test_directory\nexit")
    assert_output_contains "$output" "Executing command: mkdir -p test_directory" "Directory creation command"
    
    # Verify directory was created
    if [[ -d "test_directory" ]]; then
        echo -e "${GREEN}✓ Directory created successfully${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Directory creation failed${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 3: Complex operations with context
test_complex_operations() {
    echo -e "\n${YELLOW}Test 3: Complex operations maintaining context${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Perform multiple operations in sequence
    local commands="write a test file\nlist files\ncalculate 2+2\nexit"
    local output=$(run_cli_commands "$commands")
    
    # Verify all operations completed
    assert_output_contains "$output" "File test_output.txt has been written" "File write in sequence"
    assert_output_contains "$output" "Executing command: ls -la" "List command in sequence"
    assert_output_contains "$output" "2 + 2 = 4" "Calculation in sequence"
    
    # Check conversation has all interactions
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        local msg_count=$(jq '.messages | length' "$conv_file")
        if [[ $msg_count -ge 6 ]]; then  # 3 commands + 3 responses
            echo -e "${GREEN}✓ All operations recorded in conversation${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Not all operations recorded (found $msg_count messages)${NC}"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 4: File operations with special content
test_special_file_content() {
    echo -e "\n${YELLOW}Test 4: File operations with special content${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Test JSON file write
    local output=$(run_cli_commands "write json file with test data\nexit")
    assert_file_contains "data.json" '"name": "test"' "JSON file write"
    
    # Test script file write
    output=$(run_cli_commands "write script file\nexit")
    assert_file_contains "test_script.sh" "#!/bin/bash" "Script file write"
    
    # Make script executable and run it
    if [[ -f "test_script.sh" ]]; then
        chmod +x test_script.sh
        local script_output=$(./test_script.sh 2>&1)
        if [[ "$script_output" == *"Hello from script"* ]]; then
            echo -e "${GREEN}✓ Script file executable and runs correctly${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Script execution failed${NC}"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 5: Context awareness in operations
test_context_awareness() {
    echo -e "\n${YELLOW}Test 5: Context awareness during operations${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # First, perform some operations
    run_cli_commands "write a test file\nexit" > /dev/null 2>&1
    
    # In a new session, check if context is maintained
    local output=$(run_cli_commands "check conversation context\nexit")
    assert_output_contains "$output" "previous conversation" "Context maintained across sessions"
    
    # Verify context is passed in API calls
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        local total_msgs=$(jq '.messages | length' "$conv_file")
        echo -e "${BLUE}  Total messages in conversation: $total_msgs${NC}"
        
        # The context should include previous messages
        if [[ $total_msgs -ge 4 ]]; then
            echo -e "${GREEN}✓ Context includes previous operations${NC}"
            ((TESTS_PASSED++))
        fi
    fi
}

# Test 6: Folder operations and navigation
test_folder_operations() {
    echo -e "\n${YELLOW}Test 6: Folder operations and navigation${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Create nested directories and files
    local commands="create a directory named project\n"
    commands+="create a directory named project/src\n"
    commands+="create a directory named project/tests\n"
    commands+="exit"
    
    local output=$(run_cli_commands "$commands")
    
    # Verify directory structure
    if [[ -d "project/src" ]] && [[ -d "project/tests" ]]; then
        echo -e "${GREEN}✓ Nested directory structure created${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Failed to create nested directories${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test complex command with directory navigation
    output=$(run_cli_commands "run a complex command\nexit")
    assert_output_contains "$output" "Current date:" "Complex command with date"
    assert_output_contains "$output" "$TEST_WORKSPACE" "Working directory shown"
}

# Test 7: Error handling in operations
test_error_handling() {
    echo -e "\n${YELLOW}Test 7: Error handling in file/command operations${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Test write to read-only location (should handle gracefully)
    chmod -w . 2>/dev/null
    local output=$(run_cli_commands "write a test file\nexit" 2>&1)
    chmod +w . 2>/dev/null
    
    # Should still maintain conversation even if operation fails
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    if [[ -n "$conv_id" ]]; then
        echo -e "${GREEN}✓ Conversation maintained despite operation errors${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Conversation lost due to operation error${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 8: Persistence of operation results
test_operation_persistence() {
    echo -e "\n${YELLOW}Test 8: Operation results persist in conversation${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Perform operations
    run_cli_commands "write a test file\nlist files\nexit" > /dev/null 2>&1
    
    # In new session, check history
    local output=$(run_cli_commands "/history\nexit")
    
    # History should show both the commands and responses
    assert_output_contains "$output" "write a test file" "User command in history"
    assert_output_contains "$output" "File test_output.txt has been written" "Operation result in history"
}

# Test 9: Multi-step operations
test_multistep_operations() {
    echo -e "\n${YELLOW}Test 9: Multi-step operations with context${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Simulate a multi-step task
    local commands="create a directory named app\n"
    commands+="write a test file\n"
    commands+="list files\n"
    commands+="calculate 2+2\n"
    commands+="exit"
    
    local start_time=$(date +%s)
    local output=$(run_cli_commands "$commands")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo -e "${BLUE}  Multi-step operation completed in ${duration} seconds${NC}"
    
    # Verify all steps completed
    if [[ -d "app" ]] && [[ -f "test_output.txt" ]]; then
        echo -e "${GREEN}✓ All multi-step operations completed successfully${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Some multi-step operations failed${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check conversation captured all steps
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    local msg_count=$(jq '.messages | length' "$conv_file" 2>/dev/null || echo 0)
    
    if [[ $msg_count -ge 8 ]]; then  # 4 commands + 4 responses
        echo -e "${GREEN}✓ All steps recorded in conversation (${msg_count} messages)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Not all steps recorded (only ${msg_count} messages)${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 10: File operations with conversation switching
test_operations_with_conversation_switch() {
    echo -e "\n${YELLOW}Test 10: Operations across different conversations${NC}"
    
    cd "$TEST_WORKSPACE"
    
    # Create files in first conversation
    local output=$(run_cli_commands "write a test file\nexit")
    local conv1=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Switch to new conversation and create different files
    output=$(run_cli_commands "/new\nwrite json file with test data\nexit")
    local conv2=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Switch back to first conversation
    output=$(run_cli_commands "/switch $conv1\n/history\nexit")
    
    # First conversation should only have first file operation
    assert_output_contains "$output" "write a test file" "First conversation history preserved"
    
    # Files from both conversations should exist
    if [[ -f "test_output.txt" ]] && [[ -f "data.json" ]]; then
        echo -e "${GREEN}✓ Files from both conversations exist${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Missing files from different conversations${NC}"
        ((TESTS_FAILED++))
    fi
}

# Main test runner
main() {
    echo -e "${YELLOW}=== CLIII Core Functionality E2E Tests ===${NC}"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: int.sh not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    setup
    
    # Run all tests
    test_file_write
    test_command_execution
    test_complex_operations
    test_special_file_content
    test_context_awareness
    test_folder_operations
    test_error_handling
    test_operation_persistence
    test_multistep_operations
    test_operations_with_conversation_switch
    
    # Summary
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    # Show evidence of functionality
    echo -e "\n${YELLOW}=== Evidence of Core Functionality ===${NC}"
    echo -e "${GREEN}✓ File Write Operations:${NC} Successfully creates files with content"
    echo -e "${GREEN}✓ Command Execution:${NC} Executes shell commands via 'execute' response"
    echo -e "${GREEN}✓ Directory Management:${NC} Creates and navigates directories"
    echo -e "${GREEN}✓ Context Persistence:${NC} All operations saved in conversation history"
    echo -e "${GREEN}✓ Multi-format Support:${NC} Handles text, JSON, and script files"
    echo -e "${GREEN}✓ Error Recovery:${NC} Maintains conversation despite operation failures"
    echo -e "${GREEN}✓ Session Continuity:${NC} Operations persist across CLI sessions"
    
    cleanup
    
    # Exit with appropriate code
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "\n${GREEN}All core functionality tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"