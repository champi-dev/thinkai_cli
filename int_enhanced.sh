#!/bin/bash

# ThinkAI CLI - Enhanced with Automatic Error Recovery, Self-Healing, and Local Execution
# This version includes:
# - Automatic error recovery with exponential backoff
# - Self-healing JSON validation and repair
# - Operation journaling for crash recovery
# - Dry-run mode and operation preview
# - Automatic fixes for common errors
# - Local code execution with verification

# Color codes for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Configuration
CLIII_DIR="$HOME/.cliii"
CONV_DIR="$CLIII_DIR/conversations"
CURRENT_CONV_FILE="$CLIII_DIR/current_conversation"
CODEBASE_INDEX="$CLIII_DIR/codebase_index.json"
JOURNAL_DIR="$CLIII_DIR/journal"
BACKUP_DIR="$CLIII_DIR/backups"
CONFIG_FILE="$CLIII_DIR/config.json"

# API Configuration
BASE_URL="https://api.thinkai.net"
MAX_RETRIES=5
INITIAL_BACKOFF=1

# Modes
AGENTIC_MODE="${CLIII_AGENTIC_MODE:-true}"
DRY_RUN_MODE="${CLIII_DRY_RUN:-false}"
AUTO_FIX_MODE="${CLIII_AUTO_FIX:-true}"

# Create necessary directories
mkdir -p "$CLIII_DIR" "$CONV_DIR" "$JOURNAL_DIR" "$BACKUP_DIR"

# Initialize configuration
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
    "version": "2.0.0",
    "auto_fix": true,
    "dry_run": false,
    "max_retries": 5,
    "backup_enabled": true,
    "journal_enabled": true,
    "verification_prompts": true
}
EOF
    fi
}

# Enhanced error logging
log_error() {
    local error_msg="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local error_log="$CLIII_DIR/errors.log"
    
    echo "[$timestamp] ERROR: $error_msg" >> "$error_log"
    echo -e "${RED}Error: $error_msg${RESET}" >&2
}

# Automatic JSON repair function
repair_json() {
    local file_path="$1"
    local temp_file=$(mktemp)
    
    # Try to fix common JSON issues
    if command -v jq &> /dev/null; then
        # First attempt: try to parse with jq
        if jq . "$file_path" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$file_path"
            return 0
        fi
        
        # Second attempt: fix common issues
        # Remove trailing commas
        sed 's/,\s*}/}/g; s/,\s*]/]/g' "$file_path" > "$temp_file"
        
        # Try to parse again
        if jq . "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$file_path"
            echo -e "${GREEN}✓ Repaired JSON file: $file_path${RESET}"
            return 0
        fi
    fi
    
    # If repair failed, restore from backup if available
    local backup_file="$BACKUP_DIR/$(basename "$file_path").backup"
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$file_path"
        echo -e "${YELLOW}⚠ Restored from backup: $file_path${RESET}"
        return 0
    fi
    
    rm -f "$temp_file"
    return 1
}

# Create backup of important files
create_backup() {
    local file_path="$1"
    local backup_file="$BACKUP_DIR/$(basename "$file_path").backup"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$backup_file"
        # Keep only last 5 backups
        ls -t "$BACKUP_DIR/$(basename "$file_path").backup"* 2>/dev/null | tail -n +6 | xargs -r rm
    fi
}

# Journal operations for crash recovery
journal_operation() {
    local operation="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local journal_file="$JOURNAL_DIR/operations_$(date +%Y%m%d).json"
    
    if [[ ! -f "$journal_file" ]]; then
        echo "[]" > "$journal_file"
    fi
    
    local entry=$(jq -n --arg ts "$timestamp" --argjson op "$operation" \
        '{timestamp: $ts, operation: $op, status: "pending"}')
    
    jq ". += [$entry]" "$journal_file" > "$journal_file.tmp" && mv "$journal_file.tmp" "$journal_file"
}

# Mark operation as completed in journal
complete_journal_operation() {
    local operation_id="$1"
    local journal_file="$JOURNAL_DIR/operations_$(date +%Y%m%d).json"
    
    if [[ -f "$journal_file" ]]; then
        jq ".[\"$operation_id\"].status = \"completed\"" "$journal_file" > "$journal_file.tmp" && \
            mv "$journal_file.tmp" "$journal_file"
    fi
}

# Recover incomplete operations from journal
recover_operations() {
    local journal_file="$JOURNAL_DIR/operations_$(date +%Y%m%d).json"
    
    if [[ -f "$journal_file" ]]; then
        local pending_ops=$(jq -r '.[] | select(.status == "pending") | @json' "$journal_file" 2>/dev/null)
        
        if [[ -n "$pending_ops" ]]; then
            echo -e "${YELLOW}Found incomplete operations from previous session. Recovering...${RESET}"
            while IFS= read -r op; do
                local operation=$(echo "$op" | jq -r '.operation')
                # Re-execute the operation
                execute_operation "$operation"
            done <<< "$pending_ops"
        fi
    fi
}

# Enhanced API call with automatic retry and exponential backoff
send_to_ai_with_retry() {
    local message=$1
    local conv_id=$2
    local context=$3
    local attempt=0
    local backoff=$INITIAL_BACKOFF
    local response=""
    
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        ((attempt++))
        
        # Check network connectivity first
        if ! ping -c 1 -W 2 api.thinkai.net &>/dev/null; then
            log_error "Network connectivity issue detected"
            if [[ $AUTO_FIX_MODE == "true" ]]; then
                echo -e "${YELLOW}Attempting to fix network connectivity...${RESET}"
                # Wait for network to come back
                sleep 5
                continue
            fi
        fi
        
        # Make API call with timeout
        response=$(timeout 30 curl -s -X POST "${BASE_URL}/chat" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"$message\",\"conversation_id\":\"$conv_id\",\"context\":$context}" 2>&1)
        
        local exit_code=$?
        
        # Check for success
        if [[ $exit_code -eq 0 ]] && [[ -n "$response" ]]; then
            # Validate response is valid JSON
            if echo "$response" | jq . &>/dev/null; then
                echo "$response"
                return 0
            else
                log_error "Invalid JSON response from API"
                if [[ $AUTO_FIX_MODE == "true" ]]; then
                    # Try to extract valid JSON from response
                    local fixed_response=$(echo "$response" | grep -o '{.*}' | head -1)
                    if echo "$fixed_response" | jq . &>/dev/null; then
                        echo "$fixed_response"
                        return 0
                    fi
                fi
            fi
        fi
        
        # Log the error
        log_error "API call failed (attempt $attempt/$MAX_RETRIES): Exit code $exit_code"
        
        # If timeout occurred
        if [[ $exit_code -eq 124 ]]; then
            log_error "API call timed out"
        fi
        
        # Exponential backoff
        echo -e "${YELLOW}Retrying in ${backoff}s...${RESET}"
        sleep $backoff
        backoff=$((backoff * 2))
    done
    
    # All retries failed
    log_error "Failed to get response from API after $MAX_RETRIES attempts"
    
    # Fallback to offline mode if available
    if [[ -f "$CLIII_DIR/offline_responses.json" ]]; then
        echo -e "${YELLOW}Falling back to offline mode...${RESET}"
        local offline_response=$(jq -r '.default_response' "$CLIII_DIR/offline_responses.json" 2>/dev/null || \
            echo '{"response": "I am currently offline. Your message has been saved and will be processed when connection is restored."}')
        echo "$offline_response"
    fi
    
    return 1
}

# Enhanced conversation storage with validation
save_conversation_message() {
    local conv_id=$1
    local role=$2
    local content=$3
    local conv_file="$CONV_DIR/${conv_id}.json"
    
    # Create backup before modifying
    create_backup "$conv_file"
    
    # Initialize if doesn't exist
    if [[ ! -f "$conv_file" ]]; then
        echo '{"id":"'"$conv_id"'","messages":[],"created_at":"'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"}' > "$conv_file"
    fi
    
    # Validate JSON before modification
    if ! jq . "$conv_file" &>/dev/null; then
        log_error "Corrupted conversation file detected: $conv_file"
        if [[ $AUTO_FIX_MODE == "true" ]]; then
            repair_json "$conv_file"
        fi
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local escaped_content=$(echo "$content" | jq -Rs .)
    
    # Add message with proper error handling
    local temp_file=$(mktemp)
    if jq --arg role "$role" --argjson content "$escaped_content" --arg ts "$timestamp" \
        '.messages += [{"role": $role, "content": $content, "timestamp": $ts}]' \
        "$conv_file" > "$temp_file"; then
        mv "$temp_file" "$conv_file"
    else
        log_error "Failed to save message to conversation"
        rm -f "$temp_file"
        return 1
    fi
    
    return 0
}

# Enhanced file operation with preview and rollback
handle_file_operation_enhanced() {
    local operation=$1
    local content=$2
    local file_path=$3
    local old_content=$4
    
    # Journal the operation
    local op_json=$(jq -n --arg op "$operation" --arg path "$file_path" \
        '{type: "file", operation: $op, path: $path}')
    journal_operation "$op_json"
    
    # Preview mode
    if [[ $DRY_RUN_MODE == "true" ]]; then
        echo -e "${CYAN}[DRY RUN] Would perform: $operation on $file_path${RESET}"
        case "$operation" in
            "write"|"append")
                echo -e "${CYAN}Content preview:${RESET}"
                echo "$content" | head -20
                if [[ $(echo "$content" | wc -l) -gt 20 ]]; then
                    echo -e "${CYAN}... (truncated)${RESET}"
                fi
                ;;
        esac
        return 0
    fi
    
    # Create backup for existing files
    if [[ -f "$file_path" ]]; then
        create_backup "$file_path"
    fi
    
    # Perform the operation
    case "$operation" in
        "write")
            mkdir -p "$(dirname "$file_path")"
            if echo -e "$content" > "$file_path"; then
                echo -e "${GREEN}✓ File written: $file_path${RESET}"
                # Verify write was successful
                if [[ -f "$file_path" ]]; then
                    local written_size=$(wc -c < "$file_path")
                    local expected_size=$(echo -e "$content" | wc -c)
                    if [[ $written_size -ne $expected_size ]]; then
                        log_error "File size mismatch after write"
                        if [[ $AUTO_FIX_MODE == "true" ]]; then
                            echo -e "${YELLOW}Retrying write operation...${RESET}"
                            echo -e "$content" > "$file_path"
                        fi
                    fi
                fi
            else
                log_error "Failed to write file: $file_path"
                return 1
            fi
            ;;
        "edit")
            if [[ -f "$file_path" ]]; then
                if [[ -n "$old_content" ]]; then
                    if sed -i.bak "s|$old_content|$content|g" "$file_path"; then
                        echo -e "${GREEN}✓ File edited: $file_path${RESET}"
                        rm -f "${file_path}.bak"
                    else
                        log_error "Failed to edit file: $file_path"
                        return 1
                    fi
                else
                    if echo -e "$content" > "$file_path"; then
                        echo -e "${GREEN}✓ File content replaced: $file_path${RESET}"
                    else
                        log_error "Failed to replace file content: $file_path"
                        return 1
                    fi
                fi
            else
                log_error "File not found for editing: $file_path"
                return 1
            fi
            ;;
        "append")
            mkdir -p "$(dirname "$file_path")"
            if echo -e "$content" >> "$file_path"; then
                echo -e "${GREEN}✓ Content appended to: $file_path${RESET}"
            else
                log_error "Failed to append to file: $file_path"
                return 1
            fi
            ;;
        "delete")
            if [[ -f "$file_path" ]]; then
                if rm "$file_path"; then
                    echo -e "${GREEN}✓ File deleted: $file_path${RESET}"
                else
                    log_error "Failed to delete file: $file_path"
                    return 1
                fi
            else
                log_error "File not found for deletion: $file_path"
                return 1
            fi
            ;;
        "mkdir")
            if mkdir -p "$file_path"; then
                echo -e "${GREEN}✓ Directory created: $file_path${RESET}"
            else
                log_error "Failed to create directory: $file_path"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Enhanced command execution with verification
execute_command_enhanced() {
    local command=$1
    local working_dir=$2
    
    # Journal the operation
    local op_json=$(jq -n --arg cmd "$command" '{type: "command", command: $cmd}')
    journal_operation "$op_json"
    
    # Security check
    if [[ "$command" =~ (rm[[:space:]]+-rf[[:space:]]+/|dd[[:space:]]+if=.*of=/dev/|mkfs\.|fdisk) ]]; then
        echo -e "${RED}⚠ Potentially dangerous command detected!${RESET}"
        if [[ "${CLIII_FORCE:-false}" != "true" ]]; then
            read -p "Are you sure you want to execute this command? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                echo -e "${YELLOW}Command execution cancelled${RESET}"
                return 1
            fi
        fi
    fi
    
    # Dry run mode
    if [[ $DRY_RUN_MODE == "true" ]]; then
        echo -e "${CYAN}[DRY RUN] Would execute: $command${RESET}"
        if [[ -n "$working_dir" ]]; then
            echo -e "${CYAN}In directory: $working_dir${RESET}"
        fi
        return 0
    fi
    
    echo -e "${YELLOW}Executing: $command${RESET}"
    
    # Change directory if specified
    if [[ -n "$working_dir" ]]; then
        if [[ ! -d "$working_dir" ]]; then
            log_error "Working directory does not exist: $working_dir"
            if [[ $AUTO_FIX_MODE == "true" ]]; then
                echo -e "${YELLOW}Creating working directory...${RESET}"
                mkdir -p "$working_dir"
            else
                return 1
            fi
        fi
        pushd "$working_dir" > /dev/null 2>&1
    fi
    
    # Execute with timeout and capture output
    local output_file=$(mktemp)
    local error_file=$(mktemp)
    local exit_code
    
    # Run command with timeout
    timeout 300 bash -c "$command" > "$output_file" 2> "$error_file"
    exit_code=$?
    
    # Display output
    if [[ -s "$output_file" ]]; then
        cat "$output_file"
    fi
    
    # Display errors
    if [[ -s "$error_file" ]]; then
        echo -e "${RED}Errors:${RESET}" >&2
        cat "$error_file" >&2
    fi
    
    # Clean up temp files
    rm -f "$output_file" "$error_file"
    
    # Return to original directory
    if [[ -n "$working_dir" ]]; then
        popd > /dev/null 2>&1
    fi
    
    # Handle exit codes
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Command completed successfully${RESET}"
    elif [[ $exit_code -eq 124 ]]; then
        log_error "Command timed out after 5 minutes"
        if [[ $AUTO_FIX_MODE == "true" ]]; then
            echo -e "${YELLOW}Consider breaking this into smaller commands${RESET}"
        fi
    else
        log_error "Command failed with exit code: $exit_code"
        
        # Auto-fix common errors
        if [[ $AUTO_FIX_MODE == "true" ]]; then
            case "$command" in
                "npm "*)
                    if [[ ! -f "package.json" ]]; then
                        echo -e "${YELLOW}No package.json found. Initializing npm project...${RESET}"
                        npm init -y
                        echo -e "${YELLOW}Retrying command...${RESET}"
                        timeout 300 bash -c "$command"
                    fi
                    ;;
                "python "*)
                    if [[ "$command" =~ import[[:space:]]+([a-zA-Z0-9_]+) ]]; then
                        local module="${BASH_REMATCH[1]}"
                        echo -e "${YELLOW}Missing module detected. Installing $module...${RESET}"
                        pip install "$module"
                        echo -e "${YELLOW}Retrying command...${RESET}"
                        timeout 300 bash -c "$command"
                    fi
                    ;;
            esac
        fi
    fi
    
    return $exit_code
}

# Verification helper for users
show_verification_steps() {
    local operation_type=$1
    
    echo -e "\n${CYAN}=== Verification Steps ===${RESET}"
    
    case "$operation_type" in
        "file")
            echo -e "${GREEN}To verify file operations:${RESET}"
            echo "1. List files: ls -la"
            echo "2. Check file content: cat <filename>"
            echo "3. Verify file size: ls -lh <filename>"
            echo "4. Check file type: file <filename>"
            ;;
        "command")
            echo -e "${GREEN}To verify command execution:${RESET}"
            echo "1. Check exit status: echo \$?"
            echo "2. Verify output files were created"
            echo "3. Check running processes: ps aux | grep <process>"
            echo "4. Review logs if applicable"
            ;;
        "api")
            echo -e "${GREEN}To verify API operations:${RESET}"
            echo "1. Check conversation history: /history"
            echo "2. View current conversation: /list"
            echo "3. Check error log: cat ~/.cliii/errors.log"
            ;;
    esac
    
    echo -e "${CYAN}=======================${RESET}\n"
}

# Self-test function
run_self_test() {
    echo -e "${CYAN}Running self-test...${RESET}"
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: JSON validation
    echo -n "Testing JSON validation... "
    local test_json='{"test": "value"}'
    echo "$test_json" > /tmp/test.json
    if repair_json /tmp/test.json &>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${RESET}"
        ((tests_failed++))
    fi
    rm -f /tmp/test.json
    
    # Test 2: Network connectivity
    echo -n "Testing network connectivity... "
    if ping -c 1 -W 2 google.com &>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${RESET}"
        ((tests_failed++))
    fi
    
    # Test 3: Command execution
    echo -n "Testing command execution... "
    if execute_command_enhanced "echo 'test'" "" &>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${RESET}"
        ((tests_failed++))
    fi
    
    # Test 4: File operations
    echo -n "Testing file operations... "
    if handle_file_operation_enhanced "write" "test content" "/tmp/cliii_test.txt" "" &>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
        ((tests_passed++))
        rm -f /tmp/cliii_test.txt
    else
        echo -e "${RED}FAIL${RESET}"
        ((tests_failed++))
    fi
    
    echo -e "\n${CYAN}Self-test complete: ${GREEN}$tests_passed passed${RESET}, ${RED}$tests_failed failed${RESET}"
    
    if [[ $tests_failed -gt 0 ]]; then
        echo -e "${YELLOW}Some tests failed. The CLI may not function properly.${RESET}"
        return 1
    fi
    
    return 0
}

# Initialize everything
init_config
recover_operations

# Show enhanced welcome message
echo -e "${MAGENTA}Welcome to ThinkAI CLI v2.0 - Enhanced Edition${RESET}"
echo -e "${CYAN}Features: Auto-recovery, Self-healing, Dry-run mode, Local execution verification${RESET}"
echo -e "${CYAN}Commands: /new, /list, /switch <id>, /history, /clear, /test, /verify, exit${RESET}"

# Run self-test on first launch
if [[ ! -f "$CLIII_DIR/.tested" ]]; then
    if run_self_test; then
        touch "$CLIII_DIR/.tested"
    fi
fi

# Export functions for use in main script
export -f send_to_ai_with_retry
export -f handle_file_operation_enhanced
export -f execute_command_enhanced
export -f show_verification_steps
export -f repair_json
export -f create_backup