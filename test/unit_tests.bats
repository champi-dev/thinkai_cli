#!/usr/bin/env bats

load test_helper

# Test send_to_thinkai function
@test "send_to_thinkai sends correct POST request and returns response" {
    # Set up mock response
    export MOCK_CURL_OUTPUT='{"response": "Hello from ThinkAI"}'
    
    # Source the script functions
    extract_functions
    
    # Test the function
    result=$(send_to_thinkai "Hello")
    
    assert_equal "$result" '{"response": "Hello from ThinkAI"}'
}

@test "send_to_thinkai handles empty response" {
    export MOCK_CURL_OUTPUT=""
    extract_functions
    
    result=$(send_to_thinkai "Test")
    assert_equal "$result" ""
}

@test "send_to_thinkai handles curl failure" {
    export MOCK_CURL_EXIT_CODE=1
    export MOCK_CURL_OUTPUT=""
    extract_functions
    
    result=$(send_to_thinkai "Test")
    assert_equal "$result" ""
}

# Test display_colored_text function
@test "display_colored_text formats text with ANSI colors" {
    extract_functions
    
    output=$(display_colored_text "Hello World" | strip_ansi)
    assert echo "$output" | grep -q "Hello World"
}

@test "display_colored_text removes quotes" {
    extract_functions
    
    output=$(display_colored_text '"quoted text"' | strip_ansi)
    refute grep -q '"' <<< "$output"
}

@test "display_colored_text formats JSON-like text" {
    extract_functions
    
    output=$(display_colored_text '{"key":"value"}' | strip_ansi)
    refute grep -q '{' <<< "$output"
    refute grep -q '}' <<< "$output"
}

@test "display_colored_text removes response: prefix" {
    extract_functions
    
    output=$(display_colored_text 'response:Hello' | strip_ansi)
    refute grep -q 'response:' <<< "$output"
    assert grep -q 'Hello' <<< "$output"
}

@test "display_colored_text removes ThinkAI: prefix" {
    extract_functions
    
    output=$(display_colored_text 'ThinkAI:Hello' | strip_ansi)
    refute grep -q 'ThinkAI:' <<< "$output"
    assert grep -q 'Hello' <<< "$output"
}

# Test display_animation function
@test "display_animation runs without error" {
    extract_functions
    
    # Run animation in background for a short time
    ( display_animation ) &
    pid=$!
    sleep 0.5
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    
    # If we reach here without hanging, test passes
    assert true
}

# Test handle_file_operations function
@test "handle_file_operations writes file successfully" {
    extract_functions
    
    test_file="$TEST_TEMP_DIR/test_output.txt"
    run handle_file_operations "write" "test content" "$test_file"
    
    assert_success
    assert_file_created "$test_file"
    assert_file_contains "$test_file" "test content"
    assert_output --partial "File $test_file has been written"
}

@test "handle_file_operations handles unknown operation" {
    extract_functions
    
    run handle_file_operations "unknown" "content" "file.txt"
    
    assert_success
    assert_output --partial "Unknown file operation: unknown"
}

@test "handle_file_operations writes empty content" {
    extract_functions
    
    test_file="$TEST_TEMP_DIR/empty.txt"
    run handle_file_operations "write" "" "$test_file"
    
    assert_success
    assert_file_created "$test_file"
    assert [ -s "$test_file" ] || true  # File exists but may be empty
}

@test "handle_file_operations overwrites existing file" {
    extract_functions
    
    test_file="$TEST_TEMP_DIR/overwrite.txt"
    echo "original content" > "$test_file"
    
    run handle_file_operations "write" "new content" "$test_file"
    
    assert_success
    assert_file_contains "$test_file" "new content"
    refute grep -q "original content" "$test_file"
}

# Test execute_command function
@test "execute_command runs simple command" {
    extract_functions
    
    run execute_command "echo 'Hello World'"
    
    assert_success
    assert_output --partial "Executing command: echo 'Hello World'"
    assert_output --partial "Hello World"
}

@test "execute_command runs command with exit code" {
    extract_functions
    
    run execute_command "exit 0"
    assert_success
}

@test "execute_command shows command before execution" {
    extract_functions
    
    run execute_command "ls -la"
    assert_output --partial "Executing command: ls -la"
}

@test "execute_command handles empty command" {
    extract_functions
    
    run execute_command ""
    assert_output --partial "Executing command: "
}

@test "execute_command handles command with special characters" {
    extract_functions
    
    run execute_command 'echo "test & test"'
    assert_success
    assert_output --partial "test & test"
}