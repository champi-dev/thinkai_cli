#!/usr/bin/env bash

# Load bats libraries
export TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Load bats-support and bats-assert
load "$PROJECT_ROOT/bats-support/load.bash"
load "$PROJECT_ROOT/bats-assert/load.bash"

# Source the main script functions
export INT_SH="$PROJECT_ROOT/int.sh"

# Mock functions
mock_curl() {
    echo "$MOCK_CURL_OUTPUT"
}

# Extract functions from the script without executing main logic
extract_functions() {
    # Extract only the function definitions from int.sh
    local temp_file=$(mktemp)
    
    # Extract everything up to the main loop (before the echo "Welcome...")
    sed -n '1,/^echo.*Welcome to ThinkAI CLI/p' "$INT_SH" | head -n -1 > "$temp_file"
    
    # Source only the functions
    source "$temp_file"
    rm -f "$temp_file"
}

# Setup and teardown helpers
setup() {
    # Create temp directory for test files
    export TEST_TEMP_DIR=$(mktemp -d)
    export ORIGINAL_PATH="$PATH"
    export PATH="$TEST_DIR/mocks:$PATH"
    
    # Default mock responses
    export MOCK_CURL_OUTPUT=""
    export MOCK_CURL_EXIT_CODE=0
}

teardown() {
    # Clean up temp directory
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Restore PATH
    export PATH="$ORIGINAL_PATH"
    
    # Clean up any test files created
    rm -f test_file_*.txt
}

# Helper to capture colored output without ANSI codes
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Helper to test file creation
assert_file_created() {
    local file="$1"
    assert [ -f "$file" ]
}

# Helper to test file content
assert_file_contains() {
    local file="$1"
    local content="$2"
    assert grep -q "$content" "$file"
}