#!/bin/bash

# Comprehensive End-to-End Test Suite for ThinkAI CLI
# Tests complete user workflows with intelligent operation detection
# Ensures 100% coverage of user-facing functionality

set -euo pipefail

# Colors for beautiful output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_TEMP_DIR="$SCRIPT_DIR/e2e_temp_$$"
readonly E2E_LOG="$SCRIPT_DIR/e2e_test_log.txt"

# E2E test registry using hash tables for O(1) lookup
declare -A E2E_TESTS
declare -A E2E_RESULTS
declare -A WORKFLOW_COVERAGE

# Test statistics
E2E_TESTS_RUN=0
E2E_TESTS_PASSED=0
E2E_TESTS_FAILED=0
WORKFLOWS_TESTED=0

# Mock API server for testing
MOCK_SERVER_PID=""
MOCK_SERVER_PORT=8888

# Initialize E2E test environment
init_e2e_environment() {
    echo -e "${BLUE}🔧 Initializing E2E test environment...${NC}"
    
    # Create isolated test environment
    mkdir -p "$TEST_TEMP_DIR"
    export HOME="$TEST_TEMP_DIR"
    export PATH="$SCRIPT_DIR/mocks:$PATH"
    
    # Set up test configuration
    export CLIII_TEST_MODE=1
    export BASE_URL="http://localhost:$MOCK_SERVER_PORT"
    
    # Create mock responses directory
    mkdir -p "$TEST_TEMP_DIR/mock_responses"
    
    # Start mock API server
    start_mock_server
    
    echo -e "${GREEN}✓ E2E environment initialized${NC}"
}

# Mock API server implementation
start_mock_server() {
    echo -e "${CYAN}Starting mock API server on port $MOCK_SERVER_PORT...${NC}"
    
    # Create simple Python mock server
    cat > "$TEST_TEMP_DIR/mock_server.py" << 'EOF'
#!/usr/bin/env python3
import json
import http.server
import socketserver
from urllib.parse import urlparse, parse_qs

class MockAPIHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            request = json.loads(post_data)
            response = self.generate_response(request)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        except Exception as e:
            self.send_error(500, str(e))
    
    def generate_response(self, request):
        # Determine response based on request content
        messages = request.get('messages', [])
        if not messages:
            return {"response": "No messages provided"}
        
        last_message = messages[-1]['content'].lower()
        
        # Generate contextual responses
        if 'hello' in last_message:
            return {"response": "Hello! I'm ThinkAI. How can I help you today?"}
        elif 'create file' in last_message:
            return {"response": "I'll create that file for you.\n\n```create_file:test.txt\nHello World\n```"}
        elif 'run command' in last_message:
            return {"response": "I'll run that command.\n\n```bash\necho 'Command executed successfully'\n```"}
        elif 'analyze code' in last_message:
            return {"response": "I've analyzed your codebase. Found 10 files with 500 lines of code."}
        elif 'agentic' in last_message:
            return {"response": "Executing in agentic mode...\n\n```bash\nls -la\n```\n\n```create_file:result.txt\nOperation completed\n```"}
        else:
            return {"response": "I understand. Let me help you with that."}
    
    def log_message(self, format, *args):
        pass  # Suppress logs

with socketserver.TCPServer(("", MOCK_SERVER_PORT), MockAPIHandler) as httpd:
    httpd.serve_forever()
EOF

    # Start server in background
    python3 "$TEST_TEMP_DIR/mock_server.py" > /dev/null 2>&1 &
    MOCK_SERVER_PID=$!
    
    # Wait for server to start
    sleep 1
    
    # Verify server is running
    if ! kill -0 $MOCK_SERVER_PID 2>/dev/null; then
        echo -e "${RED}✗ Failed to start mock server${NC}"
        exit 1
    fi
}

# Stop mock server
stop_mock_server() {
    if [[ -n "$MOCK_SERVER_PID" ]] && kill -0 $MOCK_SERVER_PID 2>/dev/null; then
        kill $MOCK_SERVER_PID
        wait $MOCK_SERVER_PID 2>/dev/null || true
    fi
}

# E2E test registration
register_e2e_test() {
    local test_name="$1"
    local test_function="$2"
    local workflow="$3"
    
    E2E_TESTS["$test_name"]="$test_function"
    WORKFLOW_COVERAGE["$workflow"]=0
}

# Execute E2E test with monitoring
run_e2e_test() {
    local test_name="$1"
    local test_function="${E2E_TESTS[$test_name]}"
    
    if [[ -z "$test_function" ]]; then
        echo -e "${RED}✗ E2E test not found: $test_name${NC}"
        return 1
    fi
    
    echo -e "\n${CYAN}🔄 Running E2E Test: $test_name${NC}"
    
    # Clean test environment
    rm -rf "$HOME/.cliii"
    mkdir -p "$HOME/.cliii"
    
    # Run test with monitoring
    local start_time=$(date +%s)
    
    if (
        set -e
        $test_function
    ); then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ PASSED (${duration}s)${NC}"
        E2E_RESULTS["$test_name"]="PASSED"
        ((E2E_TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        E2E_RESULTS["$test_name"]="FAILED"
        ((E2E_TESTS_FAILED++))
    fi
    
    ((E2E_TESTS_RUN++))
}

# Utility function to run CLI command
run_cli() {
    local input="$1"
    echo "$input" | "$PROJECT_ROOT/int.sh" 2>&1
}

# E2E Test Cases

test_first_time_setup() {
    echo -e "${MAGENTA}Testing: First time user setup${NC}"
    
    # Run initial setup
    local output=$(echo -e "\n" | "$PROJECT_ROOT/int.sh" 2>&1)
    
    # Verify directories created
    [[ -d "$HOME/.cliii/conversations" ]] || {
        echo -e "${RED}✗ Conversations directory not created${NC}"
        return 1
    }
    
    [[ -d "$HOME/.cliii/context" ]] || {
        echo -e "${RED}✗ Context directory not created${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["first_time_setup"]=1
}

test_basic_conversation() {
    echo -e "${MAGENTA}Testing: Basic conversation flow${NC}"
    
    # Send a simple message
    local output=$(run_cli "hello")
    
    # Verify response received
    [[ "$output" == *"Hello! I'm ThinkAI"* ]] || {
        echo -e "${RED}✗ Did not receive expected response${NC}"
        echo "Output: $output"
        return 1
    }
    
    # Verify conversation saved
    local conv_files=("$HOME/.cliii/conversations"/conv_*.json)
    [[ ${#conv_files[@]} -gt 0 ]] || {
        echo -e "${RED}✗ Conversation not saved${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["basic_conversation"]=1
}

test_file_operations() {
    echo -e "${MAGENTA}Testing: File creation and manipulation${NC}"
    
    # Request file creation
    local output=$(run_cli "create file test.txt with content Hello World")
    
    # Verify file created
    [[ -f "test.txt" ]] || {
        echo -e "${RED}✗ File not created${NC}"
        return 1
    }
    
    # Verify content
    local content=$(cat test.txt 2>/dev/null)
    [[ "$content" == "Hello World" ]] || {
        echo -e "${RED}✗ File content incorrect${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["file_operations"]=1
}

test_command_execution() {
    echo -e "${MAGENTA}Testing: Command execution${NC}"
    
    # Request command execution
    local output=$(run_cli "run command echo test")
    
    # Verify command executed
    [[ "$output" == *"Command executed successfully"* ]] || {
        echo -e "${RED}✗ Command not executed${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["command_execution"]=1
}

test_context_persistence() {
    echo -e "${MAGENTA}Testing: Context persistence across sessions${NC}"
    
    # First conversation
    run_cli "My name is TestUser"
    
    # Get conversation ID
    local conv_id=$(cat "$HOME/.cliii/current_conversation")
    
    # New session with same conversation
    echo "$conv_id" > "$HOME/.cliii/current_conversation"
    local output=$(run_cli "What is my name?")
    
    # Should remember context
    [[ "$output" == *"TestUser"* ]] || {
        echo -e "${RED}✗ Context not preserved${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["context_persistence"]=1
}

test_codebase_analysis() {
    echo -e "${MAGENTA}Testing: Codebase analysis${NC}"
    
    # Create test project
    mkdir -p test_project/src
    echo "function main() { echo 'test'; }" > test_project/src/main.sh
    cd test_project
    
    # Request analysis
    local output=$(run_cli "analyze code")
    
    # Verify analysis performed
    [[ "$output" == *"analyzed your codebase"* ]] || {
        echo -e "${RED}✗ Codebase not analyzed${NC}"
        return 1
    }
    
    cd ..
    WORKFLOW_COVERAGE["codebase_analysis"]=1
}

test_agentic_mode() {
    echo -e "${MAGENTA}Testing: Agentic mode execution${NC}"
    
    # Enable agentic mode
    export CLIII_AGENTIC_MODE=1
    
    # Request agentic operation
    local output=$(run_cli "agentic: create a summary file")
    
    # Verify multiple operations executed
    [[ "$output" == *"Executing in agentic mode"* ]] || {
        echo -e "${RED}✗ Agentic mode not activated${NC}"
        return 1
    }
    
    # Verify file created
    [[ -f "result.txt" ]] || {
        echo -e "${RED}✗ Agentic operation did not create expected file${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["agentic_mode"]=1
}

test_error_handling() {
    echo -e "${MAGENTA}Testing: Error handling and recovery${NC}"
    
    # Stop mock server to simulate network error
    stop_mock_server
    
    # Try to send message
    local output=$(run_cli "test message" 2>&1)
    
    # Should handle error gracefully
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"Failed"* ]] || {
        echo -e "${RED}✗ Error not handled gracefully${NC}"
        return 1
    }
    
    # Restart server
    start_mock_server
    
    WORKFLOW_COVERAGE["error_handling"]=1
}

test_conversation_management() {
    echo -e "${MAGENTA}Testing: Conversation management commands${NC}"
    
    # Create multiple conversations
    run_cli "First conversation"
    run_cli "/new"
    run_cli "Second conversation"
    
    # List conversations
    local output=$(run_cli "/list")
    
    # Should show multiple conversations
    local conv_count=$(echo "$output" | grep -c "conv_")
    [[ $conv_count -ge 2 ]] || {
        echo -e "${RED}✗ Multiple conversations not listed${NC}"
        return 1
    }
    
    WORKFLOW_COVERAGE["conversation_management"]=1
}

# Register all E2E tests
register_all_e2e_tests() {
    register_e2e_test "first_time_setup" "test_first_time_setup" "first_time_setup"
    register_e2e_test "basic_conversation" "test_basic_conversation" "basic_conversation"
    register_e2e_test "file_operations" "test_file_operations" "file_operations"
    register_e2e_test "command_execution" "test_command_execution" "command_execution"
    register_e2e_test "context_persistence" "test_context_persistence" "context_persistence"
    register_e2e_test "codebase_analysis" "test_codebase_analysis" "codebase_analysis"
    register_e2e_test "agentic_mode" "test_agentic_mode" "agentic_mode"
    register_e2e_test "error_handling" "test_error_handling" "error_handling"
    register_e2e_test "conversation_management" "test_conversation_management" "conversation_management"
}

# Calculate workflow coverage
calculate_workflow_coverage() {
    local total_workflows=${#WORKFLOW_COVERAGE[@]}
    local tested_workflows=0
    
    for workflow in "${!WORKFLOW_COVERAGE[@]}"; do
        if [[ "${WORKFLOW_COVERAGE[$workflow]}" -eq 1 ]]; then
            ((tested_workflows++))
        fi
    done
    
    local coverage=0
    if [[ $total_workflows -gt 0 ]]; then
        coverage=$((tested_workflows * 100 / total_workflows))
    fi
    
    # Generate E2E coverage report
    cat > "$E2E_LOG" << EOF
ThinkAI CLI E2E Test Report
===========================
Generated: $(date)

Workflows Tested: $tested_workflows / $total_workflows
Coverage: ${coverage}%

Test Results:
EOF
    
    for test in "${!E2E_RESULTS[@]}"; do
        echo "${E2E_RESULTS[$test]}: $test" >> "$E2E_LOG"
    done | sort >> "$E2E_LOG"
    
    return $coverage
}

# Cleanup function
cleanup() {
    stop_mock_server
    rm -rf "$TEST_TEMP_DIR"
}

# Set up trap for cleanup
trap cleanup EXIT

# Main E2E test execution
main() {
    echo -e "${BLUE}🚀 ThinkAI CLI Comprehensive E2E Tests${NC}"
    echo -e "${BLUE}======================================${NC}\n"
    
    # Initialize
    init_e2e_environment
    register_all_e2e_tests
    
    # Run all E2E tests
    echo -e "\n${YELLOW}Executing E2E test workflows...${NC}"
    for test_name in "${!E2E_TESTS[@]}"; do
        run_e2e_test "$test_name"
    done
    
    # Calculate coverage
    calculate_workflow_coverage
    local coverage=$?
    
    # Display results
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 E2E Test Summary${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Tests Run:    $E2E_TESTS_RUN"
    echo -e "${GREEN}Tests Passed: $E2E_TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $E2E_TESTS_FAILED${NC}"
    echo -e "\nWorkflow Coverage: ${coverage}%"
    echo -e "Test Log: $E2E_LOG"
    
    # Exit with appropriate code
    [[ $E2E_TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

# Execute if run directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"