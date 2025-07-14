#!/bin/bash

# Comprehensive E2E Test Suite for ThinkAI CLI Progressive Coding
# This test suite validates:
# 1. CLI can code and execute commands
# 2. CLI maintains context across conversations
# 3. CLI can build progressively on previous work
# 4. All parsing features work correctly

set -e

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Test configuration
TEST_DIR="/tmp/thinkai_e2e_test_$$"
CLI_PATH="$(cd "$(dirname "$0")/.." && pwd)/int.sh"
SMART_CLI_PATH="$(cd "$(dirname "$0")/.." && pwd)/int_smart.sh"
RESULTS_DIR="$TEST_DIR/results"
CONV_ID="test_conv_$(date +%s)"

# Create test environment
setup_test_env() {
    echo -e "${CYAN}Setting up test environment...${RESET}"
    mkdir -p "$TEST_DIR"
    mkdir -p "$RESULTS_DIR"
    cd "$TEST_DIR"
    
    # Clear any existing test files
    rm -rf node_modules package*.json *.js *.py *.txt
}

# Cleanup function
cleanup() {
    echo -e "${CYAN}Cleaning up...${RESET}"
    cd /
    rm -rf "$TEST_DIR"
}

# Capture CLI output
run_cli_command() {
    local prompt=$1
    local output_file=$2
    local cli_to_use=${3:-$CLI_PATH}
    
    echo -e "${YELLOW}Testing: $prompt${RESET}"
    echo "$prompt" | timeout 30 "$cli_to_use" > "$output_file" 2>&1 || true
}

# Verify file creation
verify_file_exists() {
    local file=$1
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ File exists: $file${RESET}"
        return 0
    else
        echo -e "${RED}✗ File missing: $file${RESET}"
        return 1
    fi
}

# Verify file content
verify_file_contains() {
    local file=$1
    local content=$2
    if grep -q "$content" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓ File contains expected content${RESET}"
        return 0
    else
        echo -e "${RED}✗ File does not contain: $content${RESET}"
        return 1
    fi
}

# Verify command execution
verify_command_executed() {
    local output_file=$1
    local expected_pattern=$2
    if grep -q "$expected_pattern" "$output_file"; then
        echo -e "${GREEN}✓ Command executed successfully${RESET}"
        return 0
    else
        echo -e "${RED}✗ Command execution not found${RESET}"
        return 1
    fi
}

# Test 1: Basic file creation
test_basic_file_creation() {
    echo -e "\n${BLUE}=== Test 1: Basic File Creation ===${RESET}"
    
    run_cli_command "create a hello.js file that prints Hello World" "$RESULTS_DIR/test1_output.txt"
    
    # Verify file was created
    verify_file_exists "hello.js"
    
    # Verify content
    if [[ -f "hello.js" ]]; then
        echo "Content of hello.js:"
        cat hello.js
        verify_file_contains "hello.js" "console.log"
    fi
    
    # Check if operation was logged
    grep -q "File hello.js has been written" "$RESULTS_DIR/test1_output.txt" && \
        echo -e "${GREEN}✓ File operation logged${RESET}" || \
        echo -e "${RED}✗ File operation not logged${RESET}"
}

# Test 2: Command execution
test_command_execution() {
    echo -e "\n${BLUE}=== Test 2: Command Execution ===${RESET}"
    
    run_cli_command "create package.json for a node project and run npm init -y" "$RESULTS_DIR/test2_output.txt"
    
    # Verify package.json exists
    verify_file_exists "package.json"
    
    # Verify npm command was executed
    verify_command_executed "$RESULTS_DIR/test2_output.txt" "npm init"
}

# Test 3: Progressive coding - Create server
test_progressive_coding_create() {
    echo -e "\n${BLUE}=== Test 3: Progressive Coding - Create Server ===${RESET}"
    
    run_cli_command "create a simple express server in server.js with a GET /api/hello endpoint" "$RESULTS_DIR/test3_output.txt"
    
    # Verify server.js was created
    verify_file_exists "server.js"
    
    # Verify it contains express code
    verify_file_contains "server.js" "express"
    verify_file_contains "server.js" "/api/hello"
}

# Test 4: Progressive coding - Add to existing
test_progressive_coding_add() {
    echo -e "\n${BLUE}=== Test 4: Progressive Coding - Add Feature ===${RESET}"
    
    run_cli_command "add a POST /api/users endpoint to the existing server that accepts name and email" "$RESULTS_DIR/test4_output.txt"
    
    # Verify server.js still exists
    verify_file_exists "server.js"
    
    # Verify new endpoint was added
    verify_file_contains "server.js" "/api/users"
    verify_file_contains "server.js" "POST"
    
    # Check if both endpoints exist
    local has_hello=$(grep -c "/api/hello" server.js || echo 0)
    local has_users=$(grep -c "/api/users" server.js || echo 0)
    
    if [[ $has_hello -gt 0 ]] && [[ $has_users -gt 0 ]]; then
        echo -e "${GREEN}✓ Both endpoints present - context maintained${RESET}"
    else
        echo -e "${RED}✗ Context not maintained properly${RESET}"
    fi
}

# Test 5: Multi-file project
test_multi_file_project() {
    echo -e "\n${BLUE}=== Test 5: Multi-File Project ===${RESET}"
    
    run_cli_command "create a node project with: app.js as main file, config.js for configuration, and utils.js for helper functions" "$RESULTS_DIR/test5_output.txt"
    
    # Verify all files were created
    verify_file_exists "app.js"
    verify_file_exists "config.js"
    verify_file_exists "utils.js"
    
    # Count operations executed
    local file_ops=$(grep -c "File .* has been written" "$RESULTS_DIR/test5_output.txt" || echo 0)
    echo -e "${CYAN}Files created: $file_ops${RESET}"
}

# Test 6: Debug and fix
test_debug_and_fix() {
    echo -e "\n${BLUE}=== Test 6: Debug and Fix ===${RESET}"
    
    # Create a file with an error
    cat > buggy.js << 'EOF'
function calculateSum(a, b) {
    return a + c;  // Error: c is not defined
}
console.log(calculateSum(5, 3));
EOF
    
    run_cli_command "fix the error in buggy.js" "$RESULTS_DIR/test6_output.txt"
    
    # Verify file still exists
    verify_file_exists "buggy.js"
    
    # Verify error was fixed
    if ! grep -q "a + c" buggy.js && grep -q "a + b" buggy.js; then
        echo -e "${GREEN}✓ Error was fixed${RESET}"
    else
        echo -e "${RED}✗ Error was not fixed${RESET}"
    fi
}

# Test 7: Complex command sequence
test_complex_commands() {
    echo -e "\n${BLUE}=== Test 7: Complex Command Sequence ===${RESET}"
    
    run_cli_command "create a python script data_processor.py that reads data.csv and outputs summary.txt, then create a sample data.csv file" "$RESULTS_DIR/test7_output.txt"
    
    # Verify files were created
    verify_file_exists "data_processor.py"
    verify_file_exists "data.csv"
    
    # Verify Python script has proper structure
    verify_file_contains "data_processor.py" "import"
    verify_file_contains "data_processor.py" "data.csv"
}

# Test 8: Smart parsing features (if using smart CLI)
test_smart_parsing() {
    if [[ ! -f "$SMART_CLI_PATH" ]]; then
        echo -e "\n${YELLOW}Skipping smart parsing tests - int_smart.sh not found${RESET}"
        return
    fi
    
    echo -e "\n${BLUE}=== Test 8: Smart Parsing Features ===${RESET}"
    
    # Test auto-detection of dependencies
    run_cli_command "create a react component UserList.jsx that fetches users from an API" "$RESULTS_DIR/test8_output.txt" "$SMART_CLI_PATH"
    
    # Check if React import was added
    if [[ -f "UserList.jsx" ]]; then
        verify_file_contains "UserList.jsx" "import React"
        verify_file_contains "UserList.jsx" "useState"
    fi
}

# Test 9: Context continuity
test_context_continuity() {
    echo -e "\n${BLUE}=== Test 9: Context Continuity ===${RESET}"
    
    # Create initial file
    run_cli_command "create a todo.js file with a TodoList class" "$RESULTS_DIR/test9a_output.txt"
    
    # Add method to existing class
    run_cli_command "add an addTodo method to the TodoList class" "$RESULTS_DIR/test9b_output.txt"
    
    # Add another method
    run_cli_command "add a removeTodo method to the TodoList class" "$RESULTS_DIR/test9c_output.txt"
    
    # Verify all methods exist
    if [[ -f "todo.js" ]]; then
        local has_class=$(grep -c "class TodoList" todo.js || echo 0)
        local has_add=$(grep -c "addTodo" todo.js || echo 0)
        local has_remove=$(grep -c "removeTodo" todo.js || echo 0)
        
        if [[ $has_class -gt 0 ]] && [[ $has_add -gt 0 ]] && [[ $has_remove -gt 0 ]]; then
            echo -e "${GREEN}✓ All methods added - perfect context continuity${RESET}"
        else
            echo -e "${RED}✗ Some methods missing - context lost${RESET}"
        fi
    fi
}

# Generate test report
generate_report() {
    echo -e "\n${CYAN}=== Test Report ===${RESET}"
    
    local total_files=$(ls -1 *.{js,py,json,jsx,csv} 2>/dev/null | wc -l || echo 0)
    echo -e "${BLUE}Total files created: $total_files${RESET}"
    
    echo -e "\n${CYAN}Files created:${RESET}"
    ls -la *.{js,py,json,jsx,csv} 2>/dev/null || echo "No files found"
    
    echo -e "\n${CYAN}Test outputs saved in: $RESULTS_DIR${RESET}"
}

# Main test execution
main() {
    echo -e "${CYAN}🧪 ThinkAI CLI E2E Progressive Coding Test Suite${RESET}"
    echo -e "${CYAN}================================================${RESET}"
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Setup test environment
    setup_test_env
    
    # Run all tests
    test_basic_file_creation
    test_command_execution
    test_progressive_coding_create
    test_progressive_coding_add
    test_multi_file_project
    test_debug_and_fix
    test_complex_commands
    test_smart_parsing
    test_context_continuity
    
    # Generate report
    generate_report
    
    echo -e "\n${GREEN}✅ All tests completed!${RESET}"
    echo -e "${CYAN}Check $RESULTS_DIR for detailed outputs${RESET}"
    
    # Keep results for inspection
    echo -e "\n${YELLOW}Results directory: $TEST_DIR${RESET}"
    echo -e "${YELLOW}Run 'rm -rf $TEST_DIR' to clean up${RESET}"
    
    # Don't auto-cleanup to allow inspection
    trap - EXIT
}

# Run tests
main "$@"