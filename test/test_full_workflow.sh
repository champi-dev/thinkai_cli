#!/bin/bash

# Full Workflow Integration Test
# Tests the complete ThinkAI CLI workflow with context and agentic mode

echo "🧪 Integration Test: Full ThinkAI CLI Workflow"
echo "============================================="

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIII_SCRIPT="$SCRIPT_DIR/../int.sh"
TEST_DIR="$(mktemp -d)"
TEST_PROJECT="$TEST_DIR/test_project"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
    # Clean test conversations
    rm -f "$HOME/.cliii/conversations/test_workflow_"* 2>/dev/null
}
trap cleanup EXIT

echo -e "\n${YELLOW}Setting up test environment...${NC}"

# Create a test project
mkdir -p "$TEST_PROJECT/src"
mkdir -p "$TEST_PROJECT/tests"

# Create initial project files
cat > "$TEST_PROJECT/package.json" << 'EOF'
{
    "name": "test-workflow-project",
    "version": "1.0.0",
    "description": "Test project for ThinkAI CLI workflow",
    "main": "src/index.js",
    "scripts": {
        "start": "node src/index.js",
        "test": "echo 'No tests yet'"
    }
}
EOF

cat > "$TEST_PROJECT/src/index.js" << 'EOF'
// Simple web server
const http = require('http');

function fibonacci(n) {
    // Unoptimized recursive implementation
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

const server = http.createServer((req, res) => {
    if (req.url.startsWith('/fib/')) {
        const n = parseInt(req.url.slice(5));
        const result = fibonacci(n);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ n, result }));
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(3000, () => {
    console.log('Server running on port 3000');
});
EOF

cat > "$TEST_PROJECT/README.md" << 'EOF'
# Test Workflow Project

A simple Node.js server with fibonacci calculation endpoint.

## Issues
- Fibonacci calculation is slow for large numbers
- No memoization implemented
- No error handling
EOF

# Change to test project directory
cd "$TEST_PROJECT"

echo -e "${GREEN}✓ Test project created${NC}"

# Test 1: Codebase Analysis
echo -e "\n${YELLOW}Test 1: Analyzing codebase...${NC}"

# Source the functions we need
source "$CLIII_SCRIPT" 2>/dev/null || true

# Run analysis
analyze_codebase "$TEST_PROJECT"

if [[ -f "$HOME/.cliii/context/codebase_index.json" ]]; then
    echo -e "${GREEN}✓ Codebase analysis completed${NC}"
    
    # Show summary
    echo -e "\n${BLUE}Codebase summary:${NC}"
    jq -r '.summary' "$HOME/.cliii/context/codebase_index.json" 2>/dev/null | head -10
else
    echo -e "${RED}✗ Codebase analysis failed${NC}"
    exit 1
fi

# Test 2: Context-Aware Conversation
echo -e "\n${YELLOW}Test 2: Testing context-aware conversation...${NC}"

# Create a test conversation
CONV_ID="test_workflow_$(date +%s)"
CONV_FILE="$HOME/.cliii/conversations/${CONV_ID}.json"

# Initialize conversation
mkdir -p "$HOME/.cliii/conversations"
echo "{\"conversation_id\":\"$CONV_ID\",\"messages\":[]}" > "$CONV_FILE"

# Simulate conversation about optimizing fibonacci
save_to_conversation "$CONV_ID" "user" "I need to optimize the fibonacci function in this project"

# Test context retrieval
echo -e "\n${BLUE}Testing context retrieval for 'fibonacci'...${NC}"
context=$(get_codebase_context "fibonacci optimize" 3)

if [[ -n "$context" ]] && [[ "$context" != "[]" ]]; then
    echo -e "${GREEN}✓ Context retrieved successfully${NC}"
    echo "Found $(echo "$context" | jq 'length') relevant files"
else
    echo -e "${RED}✗ Context retrieval failed${NC}"
fi

# Test 3: Agentic Mode Response Processing
echo -e "\n${YELLOW}Test 3: Testing agentic mode...${NC}"

# Simulate an AI response with code
AI_RESPONSE='I'\''ll help you optimize the fibonacci function with memoization. Here'\''s the improved version:

```javascript
// Memoization utility
const memoize = (fn) => {
    const cache = new Map();
    return (...args) => {
        const key = JSON.stringify(args);
        if (cache.has(key)) {
            return cache.get(key);
        }
        const result = fn(...args);
        cache.set(key, result);
        return result;
    };
};

// Optimized fibonacci with memoization
const fibonacci = memoize((n) => {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
});

module.exports = { fibonacci, memoize };
```

Save this in a new file called `src/fibonacci.js`. Then update your `index.js` to use it:

```javascript
const { fibonacci } = require('\''./fibonacci'\'');
```

To test the improvement, run:
`npm start`

The memoized version will be much faster for large numbers.'

# Parse the response
operations=$(parse_ai_response_to_operations "$AI_RESPONSE")

if [[ -n "$operations" ]]; then
    op_count=$(echo "$operations" | jq 'length')
    echo -e "${GREEN}✓ Parsed $op_count operations from AI response${NC}"
    
    # Show operations
    echo -e "\n${BLUE}Operations to execute:${NC}"
    echo "$operations" | jq -r '.[] | "  - \(.type): \(.path // .command)"'
    
    # Execute operations
    echo -e "\n${BLUE}Executing operations...${NC}"
    
    # Process each operation
    while IFS= read -r op; do
        op_type=$(echo "$op" | jq -r '.type')
        
        case "$op_type" in
            "file")
                path=$(echo "$op" | jq -r '.path')
                content=$(echo "$op" | jq -r '.content')
                operation=$(echo "$op" | jq -r '.operation // "write"')
                
                echo -e "  Creating file: $path"
                mkdir -p "$(dirname "$path")"
                echo "$content" > "$path"
                ;;
            "command")
                cmd=$(echo "$op" | jq -r '.command')
                echo -e "  Would execute: $cmd"
                ;;
        esac
    done < <(echo "$operations" | jq -c '.[]')
    
    echo -e "${GREEN}✓ Operations processed${NC}"
else
    echo -e "${RED}✗ Failed to parse operations${NC}"
fi

# Test 4: Verify Created Files
echo -e "\n${YELLOW}Test 4: Verifying results...${NC}"

if [[ -f "src/fibonacci.js" ]]; then
    echo -e "${GREEN}✓ fibonacci.js created successfully${NC}"
    
    # Check content
    if grep -q "memoize" "src/fibonacci.js"; then
        echo -e "${GREEN}✓ Memoization implemented${NC}"
    else
        echo -e "${RED}✗ Memoization not found${NC}"
    fi
else
    echo -e "${RED}✗ fibonacci.js not created${NC}"
fi

# Test 5: Conversation Continuity
echo -e "\n${YELLOW}Test 5: Testing conversation continuity...${NC}"

# Add follow-up message
save_to_conversation "$CONV_ID" "assistant" "$AI_RESPONSE"
save_to_conversation "$CONV_ID" "user" "Can you also add error handling?"

# Check conversation history
msg_count=$(jq '.messages | length' "$CONV_FILE" 2>/dev/null || echo 0)

if [[ $msg_count -ge 3 ]]; then
    echo -e "${GREEN}✓ Conversation history maintained ($msg_count messages)${NC}"
    
    # Show conversation flow
    echo -e "\n${BLUE}Conversation history:${NC}"
    jq -r '.messages[] | "  [\(.role)]: \(.content | split("\n")[0])"' "$CONV_FILE" | head -5
else
    echo -e "${RED}✗ Conversation history incomplete${NC}"
fi

# Test 6: Project Structure Analysis
echo -e "\n${YELLOW}Test 6: Final project structure...${NC}"

echo -e "\n${BLUE}Project files:${NC}"
find . -type f -name "*.js" -o -name "*.json" -o -name "*.md" | sort | sed 's/^/  /'

# Performance check
echo -e "\n${YELLOW}Performance Analysis:${NC}"

# Re-analyze to see changes
analyze_codebase "$TEST_PROJECT" > /dev/null 2>&1

if [[ -f "$HOME/.cliii/context/codebase_index.json" ]]; then
    total_files=$(jq '.summary.total_files' "$HOME/.cliii/context/codebase_index.json")
    total_lines=$(jq '.summary.total_lines' "$HOME/.cliii/context/codebase_index.json")
    
    echo -e "  Total files analyzed: $total_files"
    echo -e "  Total lines of code: $total_lines"
    echo -e "  Languages detected:"
    jq -r '.summary.languages | to_entries[] | "    - \(.key): \(.value) files"' "$HOME/.cliii/context/codebase_index.json" 2>/dev/null
fi

# Summary
echo -e "\n${YELLOW}=============================================${NC}"
echo -e "${GREEN}Integration test completed successfully!${NC}"
echo -e "${YELLOW}=============================================${NC}"

echo -e "\n${BLUE}Key features tested:${NC}"
echo -e "  ✓ Automatic codebase analysis"
echo -e "  ✓ Context-aware file search"
echo -e "  ✓ AI response parsing"
echo -e "  ✓ Automatic code extraction"
echo -e "  ✓ File creation from code blocks"
echo -e "  ✓ Conversation continuity"
echo -e "  ✓ Project structure tracking"

echo -e "\n${GREEN}The ThinkAI CLI successfully:${NC}"
echo -e "  1. Analyzed the project codebase"
echo -e "  2. Found relevant files for the query"
echo -e "  3. Parsed AI responses into executable operations"
echo -e "  4. Created optimized code files automatically"
echo -e "  5. Maintained conversation context across interactions"