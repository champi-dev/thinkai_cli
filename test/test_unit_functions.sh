#!/bin/bash

# Unit Tests for ThinkAI CLI Functions
# Tests individual functions in isolation

echo "🧪 Unit Tests: ThinkAI CLI Functions"
echo "===================================="

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIII_SCRIPT="$SCRIPT_DIR/../int.sh"
TEST_DIR="$(mktemp -d)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test runner
run_test() {
    local test_name=$1
    local expected=$2
    local actual=$3
    
    echo -n "  $test_name: "
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo "    Expected: $expected"
        echo "    Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Extract only needed functions from int.sh
extract_functions() {
    # Create a minimal script with just the functions we need
    cat > "$TEST_DIR/functions.sh" << 'EOF'
#!/bin/bash

# Stub for jq availability
command -v jq &> /dev/null || { echo "jq is required for tests"; exit 1; }

EOF
    
    # Extract specific functions
    sed -n '/^parse_ai_response_to_operations()/,/^}/p' "$CLIII_SCRIPT" >> "$TEST_DIR/functions.sh"
    sed -n '/^generate_conversation_id()/,/^}/p' "$CLIII_SCRIPT" >> "$TEST_DIR/functions.sh"
    sed -n '/^get_codebase_context()/,/^}/p' "$CLIII_SCRIPT" >> "$TEST_DIR/functions.sh"
    
    # Add stubs for missing dependencies
    cat >> "$TEST_DIR/functions.sh" << 'EOF'

# Stub for codebase index
CODEBASE_INDEX="$TEST_DIR/codebase_index.json"
EOF
    
    source "$TEST_DIR/functions.sh"
}

# Initialize
extract_functions

echo -e "\n${YELLOW}Testing: parse_ai_response_to_operations${NC}"

# Test 1: Parse JavaScript code block
test_parse_js() {
    local input='Here is the code:
```javascript
const express = require("express");
const app = express();
app.listen(3000);
```'
    
    local result=$(parse_ai_response_to_operations "$input")
    local op_count=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    local has_server_js=$(echo "$result" | jq -r '.[0].path' 2>/dev/null)
    
    run_test "JavaScript code detection" "1" "$op_count"
    run_test "Server.js filename inference" "server.js" "$has_server_js"
}

# Test 2: Parse Python code block
test_parse_python() {
    local input='```python
def main():
    print("Hello World")

if __name__ == "__main__":
    main()
```'
    
    local result=$(parse_ai_response_to_operations "$input")
    local filename=$(echo "$result" | jq -r '.[0].path' 2>/dev/null)
    
    run_test "Python main detection" "main.py" "$filename"
}

# Test 3: Parse package.json
test_parse_package_json() {
    local input='```json
{
  "name": "test-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0"
  }
}
```'
    
    local result=$(parse_ai_response_to_operations "$input")
    local filename=$(echo "$result" | jq -r '.[0].path' 2>/dev/null)
    
    run_test "Package.json detection" "package.json" "$filename"
}

# Test 4: Parse commands
test_parse_commands() {
    local input='To install dependencies, run:
`npm install`
`npm start`

Then execute npm test to run tests.'
    
    local result=$(parse_ai_response_to_operations "$input")
    local cmd_count=$(echo "$result" | jq '[.[] | select(.type == "command")] | length' 2>/dev/null || echo 0)
    
    run_test "Command extraction" "3" "$cmd_count"
}

# Test 5: Parse mixed content
test_parse_mixed() {
    local input='Create a server:

```javascript
const server = require("http").createServer();
```

Run `npm init -y` to initialize.'
    
    local result=$(parse_ai_response_to_operations "$input")
    local total_ops=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    
    run_test "Mixed content parsing" "2" "$total_ops"
}

# Run parsing tests
test_parse_js
test_parse_python
test_parse_package_json
test_parse_commands
test_parse_mixed

echo -e "\n${YELLOW}Testing: generate_conversation_id${NC}"

# Test 6: Conversation ID format
test_conv_id() {
    local id=$(generate_conversation_id)
    local format_match=$(echo "$id" | grep -E '^conv_[0-9]{8}_[0-9]{6}_[0-9]+$' | wc -l)
    
    run_test "Conversation ID format" "1" "$format_match"
}

# Test 7: Conversation ID uniqueness
test_conv_id_unique() {
    local id1=$(generate_conversation_id)
    sleep 1
    local id2=$(generate_conversation_id)
    
    if [[ "$id1" != "$id2" ]]; then
        run_test "Conversation ID uniqueness" "unique" "unique"
    else
        run_test "Conversation ID uniqueness" "unique" "duplicate"
    fi
}

test_conv_id
test_conv_id_unique

echo -e "\n${YELLOW}Testing: get_codebase_context${NC}"

# Test 8: Context search with index
test_context_search() {
    # Create mock index
    cat > "$CODEBASE_INDEX" << 'EOF'
{
    "files": [
        {
            "path": "/test/fibonacci.js",
            "functions": "function fibonacci(n)",
            "imports": ""
        },
        {
            "path": "/test/memoize.js",
            "functions": "function memoize(fn)",
            "imports": ""
        },
        {
            "path": "/test/server.js",
            "functions": "",
            "imports": "const express = require('express')"
        }
    ]
}
EOF
    
    # Test search
    local result=$(get_codebase_context "fibonacci memoize" 2)
    local file_count=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    
    # Should find fibonacci.js and memoize.js
    if [[ $file_count -ge 1 ]]; then
        run_test "Context search relevance" "found" "found"
    else
        run_test "Context search relevance" "found" "not_found"
    fi
}

# Test 9: Empty query handling
test_empty_query() {
    local result=$(get_codebase_context "" 5)
    run_test "Empty query handling" "" "$result"
}

# Test 10: No index handling
test_no_index() {
    rm -f "$CODEBASE_INDEX"
    local result=$(get_codebase_context "test" 5)
    run_test "No index handling" "" "$result"
}

test_context_search
test_empty_query
test_no_index

# Test edge cases
echo -e "\n${YELLOW}Testing: Edge Cases${NC}"

# Test 11: Code block without language
test_no_lang_block() {
    local input='```
some code here
```'
    
    local result=$(parse_ai_response_to_operations "$input")
    local op_count=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    
    # Should not create operations for plain code blocks
    run_test "Plain code block handling" "0" "$op_count"
}

# Test 12: Nested backticks
test_nested_backticks() {
    local input='Run `npm install \`package\``'
    
    local result=$(parse_ai_response_to_operations "$input")
    local cmd=$(echo "$result" | jq -r '.[0].command' 2>/dev/null || "")
    
    # Should handle nested backticks gracefully
    if [[ -n "$cmd" ]]; then
        run_test "Nested backticks" "handled" "handled"
    else
        run_test "Nested backticks" "handled" "failed"
    fi
}

# Test 13: Multiple languages
test_multiple_langs() {
    local input='```javascript
console.log("JS");
```

```python
print("Python")
```'
    
    local result=$(parse_ai_response_to_operations "$input")
    local op_count=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    
    run_test "Multiple language blocks" "2" "$op_count"
}

test_no_lang_block
test_nested_backticks
test_multiple_langs

# Performance tests
echo -e "\n${YELLOW}Testing: Performance${NC}"

# Test 14: Large response handling
test_large_response() {
    # Generate large response
    local large_input="Here is code:\n"
    for i in {1..10}; do
        large_input+="\`\`\`javascript\nfunction test$i() { return $i; }\n\`\`\`\n"
    done
    
    local start_time=$(date +%s.%N)
    local result=$(parse_ai_response_to_operations "$large_input")
    local end_time=$(date +%s.%N)
    
    local op_count=$(echo "$result" | jq 'length' 2>/dev/null || echo 0)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Should process within reasonable time (< 1 second)
    if (( $(echo "$duration < 1.0" | bc -l) )); then
        run_test "Large response performance" "fast" "fast"
    else
        run_test "Large response performance" "fast" "slow ($duration s)"
    fi
    
    run_test "Large response accuracy" "10" "$op_count"
}

test_large_response

# Summary
echo -e "\n========================================"
echo -e "Unit Test Results:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "========================================"

# Exit code
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi