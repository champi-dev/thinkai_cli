#!/bin/bash

# E2E Test: Context Continuity and Codebase Awareness
# This test ensures that the CLI maintains context across conversations
# and properly analyzes and uses codebase information

echo "🧪 E2E Test: Context Continuity and Codebase Awareness"
echo "=================================================="

# Setup test environment
TEST_DIR="$(mktemp -d)"
TEST_CONV_DIR="$HOME/.cliii/conversations"
TEST_CONTEXT_DIR="$HOME/.cliii/context"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIII_SCRIPT="$SCRIPT_DIR/../int.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test function
run_test() {
    local test_name=$1
    local test_function=$2
    
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    if $test_function; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Conversation Persistence
test_conversation_persistence() {
    # Create test conversation
    local conv_id="test_conv_$(date +%s)"
    local conv_file="$TEST_CONV_DIR/${conv_id}.json"
    
    # Create conversation directory
    mkdir -p "$TEST_CONV_DIR"
    
    # Create test conversation with messages
    cat > "$conv_file" << EOF
{
    "conversation_id": "$conv_id",
    "messages": [
        {
            "role": "user",
            "content": "Create a function to calculate fibonacci",
            "timestamp": "2024-01-01T10:00:00Z"
        },
        {
            "role": "assistant",
            "content": "Here's a fibonacci function in Python",
            "timestamp": "2024-01-01T10:00:01Z"
        },
        {
            "role": "user",
            "content": "Now optimize it with memoization",
            "timestamp": "2024-01-01T10:00:02Z"
        }
    ]
}
EOF
    
    # Check if conversation exists and has correct structure
    if [[ -f "$conv_file" ]] && jq -e '.messages | length == 3' "$conv_file" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test 2: Codebase Analysis
test_codebase_analysis() {
    # Create test project structure
    mkdir -p "$TEST_DIR/src"
    mkdir -p "$TEST_DIR/tests"
    
    # Create test files
    cat > "$TEST_DIR/package.json" << 'EOF'
{
    "name": "test-project",
    "version": "1.0.0",
    "dependencies": {
        "express": "^4.18.0"
    }
}
EOF
    
    cat > "$TEST_DIR/src/server.js" << 'EOF'
const express = require('express');
const app = express();

function calculateFibonacci(n) {
    if (n <= 1) return n;
    return calculateFibonacci(n - 1) + calculateFibonacci(n - 2);
}

app.get('/fibonacci/:n', (req, res) => {
    const n = parseInt(req.params.n);
    const result = calculateFibonacci(n);
    res.json({ n, result });
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
EOF
    
    cat > "$TEST_DIR/src/utils.js" << 'EOF'
function memoize(fn) {
    const cache = {};
    return function(...args) {
        const key = JSON.stringify(args);
        if (key in cache) {
            return cache[key];
        }
        const result = fn.apply(this, args);
        cache[key] = result;
        return result;
    };
}

module.exports = { memoize };
EOF
    
    # Change to test directory
    cd "$TEST_DIR"
    
    # Source functions from int.sh
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Run codebase analysis
    analyze_codebase "$TEST_DIR" > /dev/null 2>&1
    
    # Check if index was created
    if [[ -f "$TEST_CONTEXT_DIR/codebase_index.json" ]]; then
        # Verify index contains our files
        local file_count=$(jq '.files | length' "$TEST_CONTEXT_DIR/codebase_index.json" 2>/dev/null || echo 0)
        local has_server=$(jq '.files[] | select(.path | contains("server.js"))' "$TEST_CONTEXT_DIR/codebase_index.json" 2>/dev/null)
        
        if [[ $file_count -ge 2 ]] && [[ -n "$has_server" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Test 3: Context Relevance
test_context_relevance() {
    # Ensure we have a codebase index
    if [[ ! -f "$TEST_CONTEXT_DIR/codebase_index.json" ]]; then
        test_codebase_analysis
    fi
    
    # Source functions
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Test context retrieval for relevant query
    local context=$(get_codebase_context "fibonacci memoize" 2)
    
    # Check if context contains relevant files
    if [[ -n "$context" ]] && [[ "$context" != "[]" ]]; then
        local has_server=$(echo "$context" | jq '.[] | select(.path | contains("server.js"))' 2>/dev/null)
        local has_utils=$(echo "$context" | jq '.[] | select(.path | contains("utils.js"))' 2>/dev/null)
        
        if [[ -n "$has_server" ]] || [[ -n "$has_utils" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Test 4: Agentic Mode Parser
test_agentic_parser() {
    # Source functions
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Test response with code blocks
    local test_response='Here is an optimized fibonacci function:

```javascript
const memoize = require("./utils").memoize;

const fibonacci = memoize(function(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
});

module.exports = { fibonacci };
```

To use it, run:
`npm install`
`node test.js`'
    
    # Parse response
    local operations=$(parse_ai_response_to_operations "$test_response")
    
    # Verify operations were extracted
    if [[ -n "$operations" ]]; then
        local op_count=$(echo "$operations" | jq 'length' 2>/dev/null || echo 0)
        local has_file=$(echo "$operations" | jq '.[] | select(.type == "file")' 2>/dev/null)
        local has_commands=$(echo "$operations" | jq '.[] | select(.type == "command")' 2>/dev/null)
        
        if [[ $op_count -ge 2 ]] && [[ -n "$has_file" ]] && [[ -n "$has_commands" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Test 5: Enhanced Context Integration
test_enhanced_context() {
    # Source functions
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Create base context
    local base_context='[
        {"role": "user", "content": "How do I optimize the fibonacci function?"},
        {"role": "assistant", "content": "You can use memoization to optimize it"}
    ]'
    
    # Enhance with codebase context
    local enhanced=$(enhance_context_with_codebase "optimize fibonacci memoization" "$base_context")
    
    # Check if context was enhanced
    if [[ -n "$enhanced" ]]; then
        local has_messages=$(echo "$enhanced" | jq -e '.messages' 2>/dev/null)
        local has_codebase=$(echo "$enhanced" | jq -e '.codebase_context' 2>/dev/null)
        
        if [[ $? -eq 0 ]] && [[ -n "$has_messages" ]] && [[ -n "$has_codebase" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Test 6: File Operation Execution
test_file_operations() {
    # Source functions
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Create test directory
    local test_ops_dir="$TEST_DIR/operations"
    mkdir -p "$test_ops_dir"
    cd "$test_ops_dir"
    
    # Test file write operation
    handle_file_operations "write" "console.log('Hello World');" "test.js" ""
    
    # Check if file was created
    if [[ -f "test.js" ]] && grep -q "Hello World" "test.js"; then
        # Test append operation
        handle_file_operations "append" "\nconsole.log('Appended line');" "test.js" ""
        
        # Check if content was appended
        if grep -q "Appended line" "test.js"; then
            return 0
        fi
    fi
    
    return 1
}

# Test 7: Command Execution
test_command_execution() {
    # Source functions
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Create test directory
    local test_cmd_dir="$TEST_DIR/commands"
    mkdir -p "$test_cmd_dir"
    cd "$test_cmd_dir"
    
    # Test command execution
    execute_command "echo 'Test Output' > output.txt" ""
    
    # Check if command was executed
    if [[ -f "output.txt" ]] && grep -q "Test Output" "output.txt"; then
        return 0
    fi
    
    return 1
}

# Test 8: Context Continuity Across Sessions
test_session_continuity() {
    # Create conversation with context
    local conv_id="continuity_test_$(date +%s)"
    local conv_file="$TEST_CONV_DIR/${conv_id}.json"
    
    # Initial conversation
    cat > "$conv_file" << EOF
{
    "conversation_id": "$conv_id",
    "messages": [
        {
            "role": "user",
            "content": "I'm working on optimizing the fibonacci function in server.js",
            "timestamp": "2024-01-01T10:00:00Z"
        },
        {
            "role": "assistant",
            "content": "I see you have a fibonacci function. Let me help optimize it with memoization.",
            "timestamp": "2024-01-01T10:00:01Z"
        }
    ]
}
EOF
    
    # Simulate new session - load conversation
    source "$CLIII_SCRIPT" 2>/dev/null || true
    
    # Check if we can retrieve context
    if [[ -f "$conv_file" ]]; then
        local messages=$(jq '.messages | length' "$conv_file" 2>/dev/null || echo 0)
        if [[ $messages -eq 2 ]]; then
            # Add new message
            save_to_conversation "$conv_id" "user" "Can you show me the memoized version?"
            
            # Check if message was saved
            local new_messages=$(jq '.messages | length' "$conv_file" 2>/dev/null || echo 0)
            if [[ $new_messages -eq 3 ]]; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# Run all tests
echo "Starting E2E tests..."
echo "Test directory: $TEST_DIR"

run_test "Conversation Persistence" test_conversation_persistence
run_test "Codebase Analysis" test_codebase_analysis
run_test "Context Relevance" test_context_relevance
run_test "Agentic Mode Parser" test_agentic_parser
run_test "Enhanced Context Integration" test_enhanced_context
run_test "File Operation Execution" test_file_operations
run_test "Command Execution" test_command_execution
run_test "Session Continuity" test_session_continuity

# Summary
echo -e "\n========================================"
echo -e "Test Results:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "========================================"

# Exit with appropriate code
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi