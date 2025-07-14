#!/bin/bash

# Test script for enhanced ThinkAI CLI features
# This script tests automatic error recovery, self-healing, and local execution

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/enhanced_functions.sh" 2>/dev/null || echo "Warning: Enhanced functions not found"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Test results
PASSED=0
FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -ne "Testing $test_name... "
    
    if eval "$test_command"; then
        if [[ "$expected_result" == "pass" ]]; then
            echo -e "${GREEN}PASSED${RESET}"
            ((PASSED++))
        else
            echo -e "${RED}FAILED${RESET} (expected failure)"
            ((FAILED++))
        fi
    else
        if [[ "$expected_result" == "fail" ]]; then
            echo -e "${GREEN}PASSED${RESET} (correctly failed)"
            ((PASSED++))
        else
            echo -e "${RED}FAILED${RESET}"
            ((FAILED++))
        fi
    fi
}

echo -e "${CYAN}=== Testing Enhanced ThinkAI CLI Features ===${RESET}\n"

# Test 1: JSON Repair
echo -e "${YELLOW}1. Testing JSON Repair Functionality${RESET}"
# Create corrupted JSON
echo '{"test": "value",}' > /tmp/test_corrupt.json
run_test "JSON repair" "repair_json /tmp/test_corrupt.json" "pass"
rm -f /tmp/test_corrupt.json

# Test 2: Error Logging
echo -e "\n${YELLOW}2. Testing Error Logging${RESET}"
run_test "Error logging" "log_error 'Test error message' 2>/dev/null && [[ -f ~/.cliii/errors.log ]]" "pass"

# Test 3: Backup Creation
echo -e "\n${YELLOW}3. Testing Backup Creation${RESET}"
echo "test content" > /tmp/test_backup.txt
run_test "Backup creation" "create_backup /tmp/test_backup.txt && ls ~/.cliii/backups/*test_backup* >/dev/null 2>&1" "pass"
rm -f /tmp/test_backup.txt

# Test 4: Dangerous Command Detection
echo -e "\n${YELLOW}4. Testing Dangerous Command Detection${RESET}"
export CLIII_FORCE=false
run_test "Dangerous command detection" "echo 'no' | execute_command_safe 'rm -rf /' '' 2>/dev/null" "fail"

# Test 5: Dry Run Mode
echo -e "\n${YELLOW}5. Testing Dry Run Mode${RESET}"
rm -f /tmp/should_not_exist  # Clean up from any previous runs
run_test "Dry run mode" "export CLIII_DRY_RUN=true && source enhanced_functions.sh && execute_command_safe 'touch /tmp/should_not_exist' '' >/dev/null 2>&1 && [[ ! -f /tmp/should_not_exist ]]" "pass"
export CLIII_DRY_RUN=false

# Test 6: Network Connectivity Check
echo -e "\n${YELLOW}6. Testing Network Connectivity${RESET}"
run_test "Network check" "ping -c 1 -W 2 google.com >/dev/null 2>&1" "pass"

# Test 7: Auto-fix Mode
echo -e "\n${YELLOW}7. Testing Auto-fix Mode${RESET}"
export CLIII_AUTO_FIX=true
cd /tmp
run_test "Auto-fix npm" "[[ ! -f package.json ]] && execute_command_safe 'npm --version' '' >/dev/null 2>&1" "pass"
rm -f package.json
cd - >/dev/null

# Test 8: Verification Display
echo -e "\n${YELLOW}8. Testing Verification Display${RESET}"
run_test "Verification display" "show_verification >/dev/null 2>&1" "pass"

# Summary
echo -e "\n${CYAN}=== Test Summary ===${RESET}"
echo -e "Tests passed: ${GREEN}$PASSED${RESET}"
echo -e "Tests failed: ${RED}$FAILED${RESET}"
echo -e "Total tests: $((PASSED + FAILED))"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! ✓${RESET}"
    exit 0
else
    echo -e "\n${RED}Some tests failed! ✗${RESET}"
    exit 1
fi