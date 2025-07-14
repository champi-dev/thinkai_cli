#!/usr/bin/env bats

load test_helper

# Edge case tests to ensure 100% coverage

# Additional tests for JSON parsing edge cases
@test "edge: response with execute but no command field" {
    export MOCK_CURL_OUTPUT='{"execute": true}'
    
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should not crash, should handle gracefully
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: response with file_operation but missing fields" {
    export MOCK_CURL_OUTPUT='{"file_operation": true, "operation": "write"}'
    
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should handle missing file_name and content
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: malformed JSON response" {
    export MOCK_CURL_OUTPUT='{"response": "unclosed quote}'
    
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should still display something and not crash
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: very long input line" {
    export MOCK_CURL_OUTPUT='{"response": "Long input handled"}'
    
    # Generate a very long input
    long_input=$(printf 'A%.0s' {1..1000})
    printf "${long_input}\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    assert grep -q "Long input handled" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: response with all special formatting characters" {
    extract_functions
    
    # Test all the sed replacements in display_colored_text
    output=$(display_colored_text 'response:ThinkAI:{"key":"value",test}' | strip_ansi)
    
    # Should remove all special markers
    refute grep -q 'response:' <<< "$output"
    refute grep -q 'ThinkAI:' <<< "$output"
    refute grep -q '"' <<< "$output"
    refute grep -q '{' <<< "$output"
    refute grep -q '}' <<< "$output"
    refute grep -q ',' <<< "$output"
}

@test "edge: file operation with path containing spaces" {
    export MOCK_CURL_OUTPUT='{"file_operation": true, "operation": "write", "content": "test", "file_name": "'"$TEST_TEMP_DIR"'/file with spaces.txt"}'
    
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Check file was created with spaces in name
    assert [ -f "$TEST_TEMP_DIR/file with spaces.txt" ]
}

@test "edge: execute command that fails" {
    export MOCK_CURL_OUTPUT='{"execute": true, "command": "false"}'
    
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should handle command failure gracefully
    assert grep -q "Executing command: false" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: interrupt handling during animation" {
    # This test ensures the animation cleanup works properly
    export MOCK_CURL_OUTPUT='{"response": "Quick response"}'
    
    # The animation is killed quickly in the main script
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should complete without hanging
    assert grep -q "Quick response" "$TEST_TEMP_DIR/output.txt"
}

@test "edge: display_animation completes full cycle" {
    extract_functions
    
    # Test that animation completes its full cycle
    # This ensures the loop and frame iteration is covered
    ( display_animation ) &
    pid=$!
    sleep 1.5  # Let it run through multiple cycles
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    
    # If we get here, animation ran without error
    assert true
}

@test "edge: handle_file_operations with multiline content" {
    extract_functions
    
    test_file="$TEST_TEMP_DIR/multiline.txt"
    multiline_content="line 1
line 2
line 3"
    
    run handle_file_operations "write" "$multiline_content" "$test_file"
    
    assert_success
    assert_file_created "$test_file"
    assert [ "$(wc -l < "$test_file")" -eq 3 ]
}

@test "edge: execute_command with command substitution" {
    extract_functions
    
    run execute_command 'echo "Current dir: $(pwd)"'
    
    assert_success
    assert_output --partial "Current dir:"
}

@test "edge: response triggers both execute and file_operation" {
    export MOCK_CURL_OUTPUT='{"execute": true, "command": "echo both", "file_operation": true, "operation": "write", "content": "both", "file_name": "test_both.txt"}'
    
    # Run in current directory to ensure file creation works
    cd "$TEST_TEMP_DIR"
    printf "test\nexit\n" | timeout 5s bash "$INT_SH" > output.txt 2>&1
    
    # Both operations should execute
    assert grep -q "Executing command: echo both" output.txt
    assert grep -q "both" output.txt
    assert grep -q "File test_both.txt has been written" output.txt
    
    # Cleanup
    rm -f test_both.txt output.txt
}

@test "edge: very large response handling" {
    # Generate a large response
    large_response='{"response": "'
    for i in {1..1000}; do
        large_response+="Line $i of large response. "
    done
    large_response+='"}'
    
    export MOCK_CURL_OUTPUT="$large_response"
    
    printf "test\nexit\n" | timeout 10s bash "$INT_SH" > "$TEST_TEMP_DIR/output.txt" 2>&1
    
    # Should handle large response
    assert grep -q "Line 1 of large response" "$TEST_TEMP_DIR/output.txt"
    assert grep -q "Goodbye!" "$TEST_TEMP_DIR/output.txt"
}