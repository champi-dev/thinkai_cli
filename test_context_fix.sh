#!/bin/bash

# Test script to verify context persistence fix

echo "Testing ThinkAI CLI context persistence improvements..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="$HOME/.cliii"
CONV_DIR="$TEST_DIR/conversations"

# Function to check if context is being passed correctly
check_context() {
    local conv_file="$1"
    if [[ -f "$conv_file" ]] && command -v jq &> /dev/null; then
        local msg_count=$(jq '.messages | length' "$conv_file" 2>/dev/null || echo 0)
        echo "$msg_count"
    else
        echo "0"
    fi
}

# Function to corrupt JSON (for testing repair)
corrupt_json() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # Remove closing brace to corrupt JSON
        sed -i '$ s/}$//' "$file"
    fi
}

echo -e "${YELLOW}1. Testing conversation creation and verification...${NC}"
TEST_CONV="test_conv_$(date +%s)"
CONV_FILE="$CONV_DIR/${TEST_CONV}.json"

# Create a test conversation
mkdir -p "$CONV_DIR"
echo '{"conversation_id":"'"$TEST_CONV"'","messages":[]}' > "$CONV_FILE"

# Add some messages
if command -v jq &> /dev/null; then
    # Add first message
    jq '.messages += [{"role": "user", "content": "Test message 1", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}]' "$CONV_FILE" > "$CONV_FILE.tmp" && mv "$CONV_FILE.tmp" "$CONV_FILE"
    
    # Add second message
    jq '.messages += [{"role": "assistant", "content": "Test response 1", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}]' "$CONV_FILE" > "$CONV_FILE.tmp" && mv "$CONV_FILE.tmp" "$CONV_FILE"
fi

msg_count=$(check_context "$CONV_FILE")
if [[ $msg_count -eq 2 ]]; then
    echo -e "${GREEN}✓ Conversation created successfully with $msg_count messages${NC}"
else
    echo -e "${RED}✗ Failed to create conversation properly${NC}"
fi

echo -e "\n${YELLOW}2. Testing JSON repair functionality...${NC}"
# Corrupt the JSON
corrupt_json "$CONV_FILE"

# Source the enhanced functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/enhanced_functions.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_functions.sh"
    
    # Try to repair
    if repair_json "$CONV_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ JSON repair successful${NC}"
        
        # Verify it's valid
        if jq . "$CONV_FILE" &>/dev/null; then
            echo -e "${GREEN}✓ Repaired JSON is valid${NC}"
        else
            echo -e "${RED}✗ Repaired JSON is still invalid${NC}"
        fi
    else
        echo -e "${RED}✗ JSON repair failed${NC}"
    fi
else
    echo -e "${RED}✗ Could not load enhanced functions${NC}"
fi

echo -e "\n${YELLOW}3. Testing context retrieval...${NC}"
# Test the actual context retrieval logic
if command -v jq &> /dev/null; then
    # Get last messages (simulating what send_to_thinkai does)
    base_context=$(jq -r '.messages[-10:] | map({"role": .role, "content": .content})' "$CONV_FILE" 2>/dev/null)
    
    if [[ -n "$base_context" ]] && [[ "$base_context" != "null" ]]; then
        context_count=$(echo "$base_context" | jq 'length' 2>/dev/null || echo 0)
        echo -e "${GREEN}✓ Retrieved $context_count messages for context${NC}"
    else
        echo -e "${RED}✗ Failed to retrieve context${NC}"
    fi
fi

echo -e "\n${YELLOW}4. Testing error recovery...${NC}"
# Test with non-existent file
NON_EXIST_CONV="non_existent_conv"
NON_EXIST_FILE="$CONV_DIR/${NON_EXIST_CONV}.json"

# Source int.sh functions in a subshell to test verify_conversation
(
    source "$SCRIPT_DIR/int.sh" 2>/dev/null
    if type -t verify_conversation &>/dev/null; then
        verify_conversation "$NON_EXIST_CONV" 2>&1 | grep -q "Creating new conversation" && \
            echo -e "${GREEN}✓ Correctly handles non-existent conversations${NC}" || \
            echo -e "${RED}✗ Failed to handle non-existent conversation${NC}"
    fi
)

# Clean up test files
rm -f "$CONV_FILE" "$NON_EXIST_FILE"

echo -e "\n${YELLOW}Summary:${NC}"
echo "The context persistence improvements include:"
echo "1. Better JSON validation before reading"
echo "2. Automatic repair of corrupted conversation files"
echo "3. Fallback to empty context on errors"
echo "4. Enhanced error logging and recovery"
echo "5. Verification of conversation integrity on startup"

echo -e "\n${GREEN}To enable debug mode and see context details:${NC}"
echo "export DEBUG_MODE=true"
echo "./int.sh"