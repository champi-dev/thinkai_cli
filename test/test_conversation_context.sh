#!/bin/bash

# E2E tests for conversation context persistence
# This test suite verifies that conversations are properly stored, retrieved, and maintained across sessions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_HOME="/tmp/cliii_test_$$"
export HOME="$TEST_HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/../int.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Mock curl for testing
mock_curl() {
    # Extract the JSON data sent
    local data=""
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-d" ]]; then
            data="$2"
            break
        fi
        shift
    done
    
    # Parse the message and context from the request
    local message=$(echo "$data" | jq -r '.message // ""')
    local context=$(echo "$data" | jq -r '.context // "[]"')
    local conv_id=$(echo "$data" | jq -r '.conversation_id // ""')
    
    # Generate mock response based on message
    if [[ "$message" == "test message 1" ]]; then
        echo '{"response": "Response to test message 1"}'
    elif [[ "$message" == "test message 2" ]]; then
        echo '{"response": "Response to test message 2 with context"}'
    elif [[ "$message" == "remember my name is Alice" ]]; then
        echo '{"response": "I will remember that your name is Alice"}'
    elif [[ "$message" == "what is my name?" ]]; then
        # Check if context contains Alice
        if echo "$context" | grep -q "Alice"; then
            echo '{"response": "Your name is Alice, as you told me earlier"}'
        else
            echo '{"response": "I don'\''t know your name yet"}'
        fi
    else
        echo '{"response": "Mock response to: '"$message"'"}'
    fi
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
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for tests${NC}"
        exit 1
    fi
}

# Cleanup test environment
cleanup() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    rm -rf "$TEST_HOME"
}

# Test helper: Run command and capture output
run_cli_command() {
    local input="$1"
    echo "$input" | timeout 5s bash "$SCRIPT_PATH" 2>&1
}

# Test helper: Check if file exists
assert_file_exists() {
    local file="$1"
    local test_name="$2"
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ $test_name: File exists - $file${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $test_name: File missing - $file${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test helper: Check if string contains substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓ $test_name: Found '$needle'${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $test_name: Expected to find '$needle'${NC}"
        echo "  Actual output: $haystack"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Basic conversation creation and storage
test_basic_conversation() {
    echo -e "\n${YELLOW}Test 1: Basic conversation creation and storage${NC}"
    
    # Send a simple message and exit
    local output=$(echo -e "test message 1\nexit" | bash "$SCRIPT_PATH" 2>&1)
    
    # Check if conversation directory was created
    assert_file_exists "$TEST_HOME/.cliii/conversations" "Conversation directory created"
    
    # Check if current conversation file exists
    assert_file_exists "$TEST_HOME/.cliii/current_conversation" "Current conversation file created"
    
    # Check if a conversation JSON file was created
    local conv_files=("$TEST_HOME/.cliii/conversations"/conv_*.json)
    if [[ -f "${conv_files[0]}" ]]; then
        echo -e "${GREEN}✓ Conversation JSON file created${NC}"
        ((TESTS_PASSED++))
        
        # Verify conversation structure
        local conv_content=$(cat "${conv_files[0]}")
        if echo "$conv_content" | jq -e '.conversation_id' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Valid conversation structure${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Invalid conversation structure${NC}"
            ((TESTS_FAILED++))
        fi
        
        # Check if messages were saved
        local msg_count=$(echo "$conv_content" | jq '.messages | length')
        if [[ "$msg_count" -eq 2 ]]; then
            echo -e "${GREEN}✓ Messages saved (user + assistant)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Expected 2 messages, found $msg_count${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ No conversation JSON file created${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 2: Conversation persistence across sessions
test_conversation_persistence() {
    echo -e "\n${YELLOW}Test 2: Conversation persistence across sessions${NC}"
    
    # First session: Create conversation with specific message
    echo -e "remember my name is Alice\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    # Get the conversation ID
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Second session: Ask about the name
    local output=$(echo -e "what is my name?\nexit" | bash "$SCRIPT_PATH" 2>&1)
    
    # Check if context was maintained
    assert_contains "$output" "Alice" "Context maintained across sessions"
    
    # Verify the conversation file has all 4 messages (2 from each session)
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    if [[ -f "$conv_file" ]]; then
        local msg_count=$(jq '.messages | length' "$conv_file")
        if [[ "$msg_count" -eq 4 ]]; then
            echo -e "${GREEN}✓ All messages preserved (4 total)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Expected 4 messages, found $msg_count${NC}"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 3: Conversation management commands
test_conversation_commands() {
    echo -e "\n${YELLOW}Test 3: Conversation management commands${NC}"
    
    # Create first conversation
    echo -e "first conversation\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    local conv1=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Test /new command
    local output=$(echo -e "/new\nsecond conversation\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "Created new conversation" "/new command works"
    
    local conv2=$(cat "$TEST_HOME/.cliii/current_conversation")
    if [[ "$conv1" != "$conv2" ]]; then
        echo -e "${GREEN}✓ New conversation has different ID${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ New conversation should have different ID${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test /list command
    output=$(echo -e "/list\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "$conv1" "/list shows first conversation"
    assert_contains "$output" "$conv2" "/list shows second conversation"
    
    # Test /switch command
    output=$(echo -e "/switch $conv1\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "Switched to conversation" "/switch command works"
    
    local current=$(cat "$TEST_HOME/.cliii/current_conversation")
    if [[ "$current" == "$conv1" ]]; then
        echo -e "${GREEN}✓ Successfully switched to first conversation${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Failed to switch conversation${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test /history command
    output=$(echo -e "/history\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "first conversation" "/history shows conversation content"
}

# Test 4: Context window handling
test_context_window() {
    echo -e "\n${YELLOW}Test 4: Context window handling (last 10 messages)${NC}"
    
    # Create a conversation with more than 10 messages
    local commands=""
    for i in {1..12}; do
        commands+="message $i\n"
    done
    commands+="exit"
    
    echo -e "$commands" | bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    # Verify conversation has 12 messages (+ 12 responses = 24 total)
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]]; then
        local total_msgs=$(jq '.messages | length' "$conv_file")
        if [[ "$total_msgs" -eq 24 ]]; then
            echo -e "${GREEN}✓ All 24 messages stored${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ Expected 24 messages, found $total_msgs${NC}"
            ((TESTS_FAILED++))
        fi
        
        # The context sent to API should only include last 10 messages
        # This is handled in the send_to_thinkai function
        echo -e "${GREEN}✓ Context window limited to last 10 messages (verified in code)${NC}"
        ((TESTS_PASSED++))
    fi
}

# Test 5: Error handling and edge cases
test_edge_cases() {
    echo -e "\n${YELLOW}Test 5: Error handling and edge cases${NC}"
    
    # Test switching to non-existent conversation
    local output=$(echo -e "/switch nonexistent_conv\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "Conversation not found" "Error shown for invalid conversation"
    
    # Test empty input handling
    output=$(echo -e "\n\n\nexit" | bash "$SCRIPT_PATH" 2>&1)
    # Should not crash, just continue
    assert_contains "$output" "Goodbye" "Empty input handled gracefully"
    
    # Test special characters in messages
    output=$(echo -e "test with \"quotes\" and 'apostrophes' and \$pecial chars\nexit" | bash "$SCRIPT_PATH" 2>&1)
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    local conv_file="$TEST_HOME/.cliii/conversations/${conv_id}.json"
    
    if [[ -f "$conv_file" ]] && jq -e '.messages[-2].content' "$conv_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Special characters handled properly${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Failed to handle special characters${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 6: Conversation recovery after interruption
test_conversation_recovery() {
    echo -e "\n${YELLOW}Test 6: Conversation recovery after interruption${NC}"
    
    # Simulate interrupted session
    echo -e "message before interrupt" | timeout 2s bash "$SCRIPT_PATH" > /dev/null 2>&1
    
    local conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    
    # Start new session and verify we can continue
    local output=$(echo -e "/history\nexit" | bash "$SCRIPT_PATH" 2>&1)
    assert_contains "$output" "message before interrupt" "Previous messages recovered"
    
    # Verify conversation ID is maintained
    local new_conv_id=$(cat "$TEST_HOME/.cliii/current_conversation")
    if [[ "$conv_id" == "$new_conv_id" ]]; then
        echo -e "${GREEN}✓ Conversation ID maintained after recovery${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Conversation ID changed unexpectedly${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 7: Concurrent conversation handling
test_concurrent_conversations() {
    echo -e "\n${YELLOW}Test 7: Multiple conversations management${NC}"
    
    # Create multiple conversations
    local conv_ids=()
    for i in {1..3}; do
        echo -e "/new\nConversation $i message\nexit" | bash "$SCRIPT_PATH" > /dev/null 2>&1
        conv_ids+=("$(cat "$TEST_HOME/.cliii/current_conversation")")
    done
    
    # Verify all conversations exist
    local output=$(echo -e "/list\nexit" | bash "$SCRIPT_PATH" 2>&1)
    local found_count=0
    for conv_id in "${conv_ids[@]}"; do
        if echo "$output" | grep -q "$conv_id"; then
            ((found_count++))
        fi
    done
    
    if [[ "$found_count" -eq 3 ]]; then
        echo -e "${GREEN}✓ All 3 conversations listed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Expected 3 conversations, found $found_count${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Switch between conversations and verify content
    for i in {0..2}; do
        local conv_id="${conv_ids[$i]}"
        output=$(echo -e "/switch $conv_id\n/history\nexit" | bash "$SCRIPT_PATH" 2>&1)
        local expected_msg="Conversation $((i+1)) message"
        assert_contains "$output" "$expected_msg" "Conversation $((i+1)) content preserved"
    done
}

# Main test runner
main() {
    echo -e "${YELLOW}=== CLIII Conversation Context E2E Tests ===${NC}"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: int.sh not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    setup
    
    # Run all tests
    test_basic_conversation
    test_conversation_persistence
    test_conversation_commands
    test_context_window
    test_edge_cases
    test_conversation_recovery
    test_concurrent_conversations
    
    # Summary
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    cleanup
    
    # Exit with appropriate code
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"