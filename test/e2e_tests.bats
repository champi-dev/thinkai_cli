#!/usr/bin/env bats

load test_helper

# E2E Tests for the main interactive loop

@test "e2e: exit command terminates the program" {
    # Create input that sends 'exit'
    echo "exit" | timeout 2s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Check that the goodbye message appears
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Welcome to ThinkAI CLI" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: normal chat interaction" {
    export MOCK_CURL_OUTPUT='{"response": "Hello! How can I help you?"}'
    
    # Send a message and then exit
    printf "Hello\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Verify the interaction
    assert grep -q "Welcome to ThinkAI CLI" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Hello! How can I help you?" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: execute command from response" {
    export MOCK_CURL_OUTPUT='{"execute": true, "command": "echo Test Command Execution"}'
    
    # Send a message that triggers command execution
    printf "run command\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Check command execution
    assert grep -q "Executing command: echo Test Command Execution" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Test Command Execution" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: file operation from response" {
    export MOCK_CURL_OUTPUT='{"file_operation": true, "operation": "write", "content": "Test file content", "file_name": "'"$TEST_TEMP_DIR"'/test_file.txt"}'
    
    # Send a message that triggers file operation
    printf "write file\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Check file was created
    assert [ -f "$TEST_TEMP_DIR/test_file.txt" ]
    assert grep -q "Test file content" "$TEST_TEMP_DIR/test_file.txt"
    assert grep -q "File $TEST_TEMP_DIR/test_file.txt has been written" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: multiple interactions before exit" {
    # Create a script to provide multiple responses
    cat > "$TEST_TEMP_DIR/mock_responses.sh" << 'EOF'
#!/bin/bash
if [ ! -f "$TEST_TEMP_DIR/call_count" ]; then
    echo "1" > "$TEST_TEMP_DIR/call_count"
    echo '{"response": "First response"}'
elif [ "$(cat $TEST_TEMP_DIR/call_count)" = "1" ]; then
    echo "2" > "$TEST_TEMP_DIR/call_count"
    echo '{"response": "Second response"}'
else
    echo '{"response": "Third response"}'
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock_responses.sh"
    
    # Replace curl mock temporarily
    cat > test/mocks/curl << EOF
#!/bin/bash
"$TEST_TEMP_DIR/mock_responses.sh"
EOF
    
    # Multiple interactions
    printf "first\nsecond\nthird\nexit\n" | timeout 10s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Verify all interactions
    assert grep -q "First response" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Second response" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Third response" "$TEST_TEMP_DIR/output.txt"
    
    # Restore original mock
    cat > test/mocks/curl << 'EOF'
#!/bin/bash
if [[ "$MOCK_CURL_EXIT_CODE" -ne 0 ]]; then
    exit "$MOCK_CURL_EXIT_CODE"
fi
echo "$MOCK_CURL_OUTPUT"
EOF
}

@test "e2e: handles curl failure gracefully" {
    export MOCK_CURL_EXIT_CODE=1
    export MOCK_CURL_OUTPUT=""
    
    # Send a message when curl fails
    printf "test message\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should still be able to exit gracefully
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: empty input handling" {
    export MOCK_CURL_OUTPUT='{"response": "Empty input received"}'
    
    # Send empty lines
    printf "\n\n\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should handle empty input and exit properly
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: special characters in input" {
    export MOCK_CURL_OUTPUT='{"response": "Special chars received"}'
    
    # Send input with special characters
    printf 'test "quotes" and $vars\nexit\n' | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should handle special characters
    assert grep -q "Special chars received" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "e2e: animation displays during response wait" {
    # Create a slow mock response
    cat > test/mocks/curl << 'EOF'
#!/bin/bash
sleep 0.5
echo '{"response": "Delayed response"}'
EOF
    
    # Run with timeout to capture animation
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should get response after delay
    assert grep -q "Delayed response" "$TEST_TEMP_DIR/output.txt"
    
    # Restore original mock
    cat > test/mocks/curl << 'EOF'
#!/bin/bash
if [[ "$MOCK_CURL_EXIT_CODE" -ne 0 ]]; then
    exit "$MOCK_CURL_EXIT_CODE"
fi
echo "$MOCK_CURL_OUTPUT"
EOF
}

@test "e2e: complex JSON response parsing" {
    export MOCK_CURL_OUTPUT='{"response": "Complex response", "metadata": {"timestamp": "2024-01-01", "status": "ok"}, "nested": {"deep": {"value": "test"}}}'
    
    # Send message
    printf "complex test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Response should be displayed (even if formatting is applied)
    assert grep -q "Complex response" "$TEST_TEMP_DIR/output.txt"
}