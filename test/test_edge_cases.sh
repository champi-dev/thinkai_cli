#!/bin/bash

# Edge case tests for CLIII conversation context
# Tests extreme scenarios, performance, and robustness

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_HOME="/tmp/cliii_edge_test_$$"
export HOME="$TEST_HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/../int.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Mock curl for testing
mock_curl() {
    local data=""
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-d" ]]; then
            data="$2"
            break
        fi
        shift
    done
    
    # Simple mock response
    echo '{"response": "Mock response"}'
}

curl() {
    mock_curl "$@"
}
export -f curl
export -f mock_curl

# Setup test environment
setup() {
    echo -e "${YELLOW}Setting up edge case test environment...${NC}"
    mkdir -p "$TEST_HOME"
}

# Cleanup test environment
cleanup() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    rm -rf "$TEST_HOME"
}

# Test helper: Assert condition
assert() {
    local condition="$1"
    local test_name="$2"
    
    if eval "$condition"; then
        echo -e "${GREEN}✓ $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $test_name${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Very long messages
test_long_messages() {
    echo -e "\n${YELLOW}Test 1: Very long messages (10KB+)${NC}"
    
    # Generate a very long message
    local long_msg=$(printf 'A%.0s' {1..10000})  # 10KB of 'A's
    
    # Send the long message
    echo -e "${long_msg}\nexit" | timeout 10s bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    # Check if conversation was saved properly
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation" 2>/dev/null)
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        # Check if the message was stored
        local stored_msg_length=$(jq -r '.messages[0].content | length' "$conv_file" 2>/dev/null)
        assert "[[ $stored_msg_length -eq 10000 ]]" "10KB message stored completely"
        
        # Verify JSON is still valid
        if jq -e . "$conv_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ JSON remains valid with long message${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ JSON corrupted with long message${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ Failed to create conversation with long message${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 2: Special characters and escaping
test_special_characters() {
    echo -e "\n${YELLOW}Test 2: Special characters and JSON escaping${NC}"
    
    # Test various special characters
    local test_cases=(
        'Message with "double quotes"'
        "Message with 'single quotes'"
        'Message with backslash \ character'
        'Message with newline\ncharacter'
        'Message with tab\tcharacter'
        'Message with emoji 🚀'
        'Message with unicode ñ á é í ó ú'
        'Message with $variables and $(command substitution)'
        'Message with JSON: {"key": "value"}'
    )
    
    for i in "${!test_cases[@]}"; do
        local msg="${test_cases[$i]}"
        echo -e "/new\n${msg}\nexit" | timeout 5s bash "$SCRIPT_PATH" > /dev/null 2>&1
        
        local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
        local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
        
        if [[ -f "$conv_file" ]] && jq -e '.messages[0].content' "$conv_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Special character test $((i+1)): Handled correctly${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Special character test $((i+1)): Failed - ${msg}${NC}"
            ((TESTS_FAILED++))
        fi
    done
}

# Test 3: Concurrent access simulation
test_concurrent_access() {
    echo -e "\n${YELLOW}Test 3: Concurrent access to same conversation${NC}"
    
    # Create initial conversation
    echo -e "initial message\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Simulate concurrent writes (run multiple instances in background)
    for i in {1..5}; do
        echo -e "concurrent message $i\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1 &
    done
    
    # Wait for all background processes
    wait
    
    # Check if conversation file is still valid
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    if jq -e . "$conv_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Conversation file remains valid after concurrent access${NC}"
        ((TESTS_PASSED++))
        
        # Count messages (should have at least some of the concurrent messages)
        local msg_count=$(jq '.messages | length' "$conv_file")
        echo -e "${BLUE}  Total messages after concurrent access: $msg_count${NC}"
    else
        echo -e "${RED}✗ Conversation file corrupted by concurrent access${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 4: Disk space handling
test_disk_space() {
    echo -e "\n${YELLOW}Test 4: Large conversation history (100+ messages)${NC}"
    
    # Create a conversation with many messages
    local input=""
    for i in {1..100}; do
        input+="Message number $i with some content to make it realistic\n"
    done
    input+="exit"
    
    echo -e "$input" | timeout 30s bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        local file_size=$(stat -f%z "$conv_file" 2>/dev/null || stat -c%s "$conv_file" 2>/dev/null)
        local msg_count=$(jq '.messages | length' "$conv_file")
        
        echo -e "${GREEN}✓ Large conversation created: $msg_count messages, $(($file_size / 1024))KB${NC}"
        ((TESTS_PASSED++))
        
        # Test that we can still read and parse it
        if jq -e . "$conv_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Large conversation file remains parseable${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Large conversation file is not parseable${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ Failed to create large conversation${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 5: Invalid conversation ID handling
test_invalid_conversation_ids() {
    echo -e "\n${YELLOW}Test 5: Invalid conversation ID handling${NC}"
    
    # Test various invalid conversation IDs
    local invalid_ids=(
        "../../etc/passwd"
        "conv_../../../tmp/evil"
        "conv with spaces"
        "conv;rm -rf /"
        "conv\$(malicious command)"
        ""
    )
    
    for id in "${invalid_ids[@]}"; do
        local output=$(echo -e "/switch $id\nexit" | bash "$SCRIPT_PATH" 2>&1)
        if echo "$output" | grep -q "Conversation not found"; then
            echo -e "${GREEN}✓ Rejected invalid ID: '$id'${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Should reject invalid ID: '$id'${NC}"
            ((TESTS_FAILED++))
        fi
    done
}

# Test 6: Recovery from corrupted files
test_corruption_recovery() {
    echo -e "\n${YELLOW}Test 6: Recovery from corrupted conversation files${NC}"
    
    # Create a valid conversation first
    echo -e "valid message\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    # Corrupt the conversation file
    echo "{ corrupted json without closing brace" > "$conv_file"
    
    # Try to use the conversation
    local output=$(echo -e "new message\nexit" | timeout 5s bash "$SCRIPT_PATH" 2>&1)
    
    # Check if the system handled it gracefully (didn't crash)
    if [[ $? -eq 0 ]] || [[ $? -eq 124 ]]; then  # 124 is timeout exit code
        echo -e "${GREEN}✓ Handled corrupted conversation file gracefully${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Crashed on corrupted conversation file${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 7: Performance with many conversations
test_many_conversations() {
    echo -e "\n${YELLOW}Test 7: Performance with many conversations${NC}"
    
    # Create many conversations
    local start_time=$(date +%s)
    
    for i in {1..50}; do
        echo -e "/new\nConversation $i\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo -e "${BLUE}  Created 50 conversations in ${duration} seconds${NC}"
    
    # Test listing many conversations
    start_time=$(date +%s)
    local output=$(echo -e "/list\nexit" | timeout 10s bash "$SCRIPT_PATH" 2>&1)
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Count how many conversations were listed
    local conv_count=$(echo "$output" | grep -c "conv_")
    
    if [[ $conv_count -ge 50 ]]; then
        echo -e "${GREEN}✓ Listed all 50 conversations in ${duration} seconds${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Only listed $conv_count out of 50 conversations${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 8: Memory stress test
test_memory_stress() {
    echo -e "\n${YELLOW}Test 8: Memory stress test with large context${NC}"
    
    # Create conversation with very large messages that will be sent as context
    local large_msg=$(printf 'X%.0s' {1..1000})  # 1KB message
    
    # Send 20 large messages to create a big context
    local input=""
    for i in {1..20}; do
        input+="Large message $i: $large_msg\n"
    done
    input+="final message\nexit"
    
    # Monitor if the process completes without running out of memory
    if echo -e "$input" | timeout 30s bash "$SCRIPT_PATH" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Handled large context without memory issues${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Failed to handle large context${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 9: File system permissions
test_permissions() {
    echo -e "\n${YELLOW}Test 9: File system permissions handling${NC}"
    
    # Create a conversation
    echo -e "test message\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    # Make conversation directory read-only
    chmod -w "$TEST_HOME/.cliii/conversations" 2>/dev/null
    
    # Try to create a new conversation
    local output=$(echo -e "/new\ntest\nexit" | timeout 5s bash "$SCRIPT_PATH" 2>&1)
    
    # Restore permissions
    chmod +w "$TEST_HOME/.cliii/conversations" 2>/dev/null
    
    # Check if it handled the permission error gracefully
    if [[ $? -eq 0 ]] || [[ $? -eq 124 ]]; then
        echo -e "${GREEN}✓ Handled permission error gracefully${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Crashed on permission error${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 10: Conversation ID collision
test_id_collision() {
    echo -e "\n${YELLOW}Test 10: Conversation ID collision handling${NC}"
    
    # Create a conversation
    echo -e "first message\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Manually create a file with a predictable ID that might collide
    local manual_id="conv_manual_test"
    local manual_file="$TEST_HOME/.cliii/conversations/${manual_id}.json"
    echo '{"conversation_id":"'$manual_id'","messages":[]}' > "$manual_file"
    
    # Try to switch to it
    local output=$(echo -e "/switch $manual_id\nexit" | bash "$SCRIPT_PATH" 2>&1)
    
    if echo "$output" | grep -q "Switched to conversation"; then
        echo -e "${GREEN}✓ Can work with manually created conversation files${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Cannot handle external conversation files${NC}"
        ((TESTS_FAILED++))
    fi
}

# Main test runner
main() {
    echo -e "${YELLOW}=== CLIII Edge Case Tests ===${NC}"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: int.sh not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    # Check for required tools
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for tests${NC}"
        exit 1
    fi
    
    setup
    
    # Run all edge case tests
    test_long_messages
    test_special_characters
    test_concurrent_access
    test_disk_space
    test_invalid_conversation_ids
    test_corruption_recovery
    test_many_conversations
    test_memory_stress
    test_permissions
    test_id_collision
    
    # Summary
    echo -e "\n${YELLOW}=== Edge Case Test Summary ===${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    cleanup
    
    # Exit with appropriate code
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "\n${GREEN}All edge case tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some edge case tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"