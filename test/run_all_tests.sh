#!/bin/bash

# Master Test Runner for ThinkAI CLI
# Runs all test suites and provides comprehensive results

echo "🧪 ThinkAI CLI - Comprehensive Test Suite"
echo "========================================"
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Results tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a test suite
run_test_suite() {
    local suite_name=$1
    local test_script=$2
    
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: $suite_name${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    ((TOTAL_SUITES++))
    
    if [[ -f "$test_script" ]] && [[ -x "$test_script" ]]; then
        if "$test_script"; then
            echo -e "\n${GREEN}✓ $suite_name PASSED${NC}"
            ((PASSED_SUITES++))
        else
            echo -e "\n${RED}✗ $suite_name FAILED${NC}"
            ((FAILED_SUITES++))
        fi
    else
        echo -e "${RED}✗ Test script not found or not executable: $test_script${NC}"
        ((FAILED_SUITES++))
    fi
}

# Start time
START_TIME=$(date +%s)

echo -e "${BLUE}Test Environment:${NC}"
echo "  OS: $(uname -s)"
echo "  Bash: ${BASH_VERSION}"
echo "  jq: $(jq --version 2>/dev/null || echo 'not installed')"
echo "  Working Directory: $(pwd)"
echo "  Test Directory: $TEST_DIR"

# Check prerequisites
echo -e "\n${BLUE}Checking prerequisites...${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗ jq is required but not installed${NC}"
    echo "  Install with: sudo apt-get install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}✗ curl is required but not installed${NC}"
    echo "  Install with: sudo apt-get install curl"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Run test suites
echo -e "\n${BLUE}Starting test execution...${NC}"

# Original tests
if [[ -f "$TEST_DIR/test_core_functionality.sh" ]]; then
    run_test_suite "Core Functionality Tests" "$TEST_DIR/test_core_functionality.sh"
fi

if [[ -f "$TEST_DIR/test_conversation_context.sh" ]]; then
    run_test_suite "Original Context Tests" "$TEST_DIR/test_conversation_context.sh"
fi

if [[ -f "$TEST_DIR/test_edge_cases.sh" ]]; then
    run_test_suite "Edge Case Tests" "$TEST_DIR/test_edge_cases.sh"
fi

# New comprehensive tests
run_test_suite "Unit Function Tests" "$TEST_DIR/test_unit_functions.sh"
run_test_suite "Context Continuity E2E Tests" "$TEST_DIR/test_context_continuity.sh"
run_test_suite "Full Workflow Integration Test" "$TEST_DIR/test_full_workflow.sh"

# Parser-specific test
if [[ -f "$TEST_DIR/../test_parser.sh" ]]; then
    run_test_suite "Agentic Parser Test" "$TEST_DIR/../test_parser.sh"
fi

# End time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary Report
echo -e "\n\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 TEST SUMMARY REPORT${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLUE}Test Suites:${NC}"
echo -e "  Total:  $TOTAL_SUITES"
echo -e "  ${GREEN}Passed: $PASSED_SUITES${NC}"
echo -e "  ${RED}Failed: $FAILED_SUITES${NC}"

# Calculate pass rate
if [[ $TOTAL_SUITES -gt 0 ]]; then
    PASS_RATE=$((PASSED_SUITES * 100 / TOTAL_SUITES))
    echo -e "\n${BLUE}Pass Rate: ${NC}${PASS_RATE}%"
    
    # Visual progress bar
    echo -n "  ["
    FILLED=$((PASS_RATE / 5))
    for ((i=0; i<20; i++)); do
        if [[ $i -lt $FILLED ]]; then
            echo -n "█"
        else
            echo -n "░"
        fi
    done
    echo "]"
fi

echo -e "\n${BLUE}Duration:${NC} ${DURATION} seconds"

# Overall result
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}The ThinkAI CLI is working correctly with:${NC}"
    echo -e "  ✓ Context awareness and continuity"
    echo -e "  ✓ Codebase analysis and indexing"
    echo -e "  ✓ Agentic mode with automatic execution"
    echo -e "  ✓ Conversation persistence"
    echo -e "  ✓ File and command operations"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}Please review the failing tests above.${NC}"
    exit 1
fi