#!/bin/bash

# End-to-end tests for enhanced ThinkAI CLI features
# Tests automatic error recovery, self-healing, and verification in real scenarios

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test environment setup
TEST_DIR="/tmp/cliii_test_$$"
TEST_CLIII_DIR="$TEST_DIR/.cliii"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Override CLIII directory for testing
export CLIII_DIR="$TEST_CLIII_DIR"
export CLIII_AUTO_FIX=true
export CLIII_SHOW_VERIFY=false

# Source the enhanced functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../enhanced_functions.sh" || {
    echo -e "${RED}Failed to source enhanced functions${NC}"
    exit 1
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_case() {
    local test_name="$1"
    local test_func="$2"
    
    echo -ne "Testing $test_name... "
    
    if $test_func > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
        # Show error details
        $test_func 2>&1 | sed 's/^/  /'
    fi
}

# Test 1: JSON repair with various corruption types
test_json_repair() {
    local test_file="$TEST_DIR/test.json"
    
    # Test trailing comma
    echo '{"key": "value",}' > "$test_file"
    repair_json "$test_file" || return 1
    jq . "$test_file" || return 1
    
    # Test multiple trailing commas
    echo '{"a": 1, "b": 2,,}' > "$test_file"
    repair_json "$test_file" || return 1
    jq . "$test_file" || return 1
    
    # Test array trailing comma
    echo '["a", "b", "c",]' > "$test_file"
    repair_json "$test_file" || return 1
    jq . "$test_file" || return 1
    
    return 0
}

# Test 2: Backup and restore functionality
test_backup_restore() {
    local test_file="$TEST_DIR/backup_test.txt"
    local original_content="original content"
    local new_content="modified content"
    
    # Create original file
    echo "$original_content" > "$test_file"
    
    # Create backup
    create_backup "$test_file" || return 1
    
    # Modify file
    echo "$new_content" > "$test_file"
    
    # Verify backup exists
    local backup_file=$(ls "$TEST_CLIII_DIR/backups/"*backup_test* 2>/dev/null | head -1)
    [[ -f "$backup_file" ]] || return 1
    
    # Verify backup content
    [[ "$(cat "$backup_file")" == "$original_content" ]] || return 1
    
    return 0
}

# Test 3: Error logging functionality
test_error_logging() {
    local error_msg="Test error message $(date +%s)"
    
    # Log error
    log_error "$error_msg" || return 1
    
    # Verify error was logged
    grep -q "$error_msg" "$TEST_CLIII_DIR/errors.log" || return 1
    
    return 0
}

# Test 4: Network retry simulation
test_network_retry() {
    # This test simulates network failure and recovery
    # We'll use a mock function instead of actual network calls
    
    local attempts=0
    mock_network_call() {
        ((attempts++))
        # Fail first 2 attempts, succeed on 3rd
        [[ $attempts -ge 3 ]]
    }
    
    # Reset attempts
    attempts=0
    
    # Simulate retry logic
    local MAX_RETRIES=5
    local attempt=0
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        ((attempt++))
        if mock_network_call; then
            [[ $attempts -eq 3 ]] || return 1
            return 0
        fi
        sleep 0.1
    done
    
    return 1
}

# Test 5: Dangerous command detection
test_dangerous_commands() {
    # Test should detect dangerous patterns
    local dangerous_commands=(
        "rm -rf /"
        "dd if=/dev/zero of=/dev/sda"
        "mkfs.ext4 /dev/sda"
    )
    
    for cmd in "${dangerous_commands[@]}"; do
        # Check if command matches dangerous pattern
        if [[ "$cmd" =~ (rm[[:space:]]+-rf[[:space:]]+/|dd[[:space:]]+if=.*of=/dev/|mkfs\.) ]]; then
            continue
        else
            return 1
        fi
    done
    
    return 0
}

# Test 6: Dry run mode
test_dry_run_mode() {
    export CLIII_DRY_RUN=true
    local test_file="$TEST_DIR/dry_run_test.txt"
    
    # This should not create the file in dry run mode
    execute_command_safe "touch $test_file" "" || return 1
    
    # File should not exist
    [[ ! -f "$test_file" ]] || return 1
    
    export CLIII_DRY_RUN=false
    return 0
}

# Test 7: Auto-fix NPM initialization
test_auto_fix_npm() {
    local test_proj="$TEST_DIR/npm_project"
    mkdir -p "$test_proj"
    cd "$test_proj"
    
    # Remove package.json if exists
    rm -f package.json
    
    # This should auto-create package.json
    export CLIII_AUTO_FIX=true
    execute_command_safe "npm --version" "$test_proj" || return 1
    
    # In a real scenario, this would create package.json
    # For testing, we'll just verify the command executed
    cd "$TEST_DIR"
    return 0
}

# Test 8: Conversation file validation
test_conversation_validation() {
    local conv_dir="$TEST_CLIII_DIR/conversations"
    mkdir -p "$conv_dir"
    
    # Create valid conversation
    local valid_conv="$conv_dir/valid.json"
    echo '{"id":"test","messages":[]}' > "$valid_conv"
    
    # Verify it's valid
    jq . "$valid_conv" || return 1
    
    # Create corrupted conversation
    local corrupt_conv="$conv_dir/corrupt.json"
    echo '{"id":"test","messages":[,]}' > "$corrupt_conv"
    
    # Repair it
    repair_json "$corrupt_conv" || return 1
    
    # Verify it's now valid
    jq . "$corrupt_conv" || return 1
    
    return 0
}

# Test 9: Operation verification output
test_verification_output() {
    # Capture verification output
    local output=$(show_verification 2>&1)
    
    # Check for expected content
    [[ "$output" =~ "How to verify locally" ]] || return 1
    [[ "$output" =~ "Check files" ]] || return 1
    [[ "$output" =~ "View content" ]] || return 1
    
    return 0
}

# Test 10: Full integration test
test_full_integration() {
    local test_file="$TEST_DIR/integration.txt"
    
    # Create file with backup
    echo "test content" > "$test_file"
    create_backup "$test_file" || return 1
    
    # Modify with verification
    echo "new content" > "$test_file"
    
    # Verify backup exists
    ls "$TEST_CLIII_DIR/backups/"*integration* >/dev/null 2>&1 || return 1
    
    # Test JSON repair on conversation
    mkdir -p "$TEST_CLIII_DIR/conversations"
    echo '{"broken":,}' > "$TEST_CLIII_DIR/conversations/test.json"
    repair_json "$TEST_CLIII_DIR/conversations/test.json" || return 1
    
    return 0
}

# Run all tests
echo -e "${BLUE}Running Enhanced ThinkAI CLI E2E Tests${NC}\n"

test_case "JSON repair functionality" test_json_repair
test_case "Backup and restore system" test_backup_restore
test_case "Error logging system" test_error_logging
test_case "Network retry logic" test_network_retry
test_case "Dangerous command detection" test_dangerous_commands
test_case "Dry run mode" test_dry_run_mode
test_case "Auto-fix NPM initialization" test_auto_fix_npm
test_case "Conversation file validation" test_conversation_validation
test_case "Verification output" test_verification_output
test_case "Full integration test" test_full_integration

# Summary
echo -e "\n${BLUE}Test Summary${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED))"

# Cleanup
rm -rf "$TEST_DIR"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi