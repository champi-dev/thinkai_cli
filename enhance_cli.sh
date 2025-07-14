#!/bin/bash

# Script to enhance the existing int.sh with automatic error recovery and self-healing capabilities
# This script patches the original int.sh file to add new features while preserving existing functionality

echo "Enhancing ThinkAI CLI with automatic error recovery and self-healing..."

# Backup original file
cp int.sh int.sh.backup.$(date +%Y%m%d_%H%M%S)

# Create enhanced functions file
cat > enhanced_functions.sh << 'EOF'
# Enhanced Functions for ThinkAI CLI
# These functions add automatic error recovery, self-healing, and verification capabilities

# Configuration for enhanced features
CLIII_DIR="$HOME/.cliii"
MAX_RETRIES=5
INITIAL_BACKOFF=1
AUTO_FIX_MODE="${CLIII_AUTO_FIX:-true}"
DRY_RUN_MODE="${CLIII_DRY_RUN:-false}"

# Enhanced error logging
log_error() {
    local error_msg="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local error_log="$CLIII_DIR/errors.log"
    mkdir -p "$CLIII_DIR"
    echo "[$timestamp] ERROR: $error_msg" >> "$error_log"
    echo -e "\033[1;31mError: $error_msg\033[0m" >&2
}

# JSON repair function
repair_json() {
    local file_path="$1"
    local temp_file=$(mktemp)
    
    if command -v jq &> /dev/null; then
        # Try to parse with jq
        if jq . "$file_path" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$file_path"
            return 0
        fi
        
        # Fix common issues
        sed 's/,\s*}/}/g; s/,\s*]/]/g' "$file_path" > "$temp_file"
        
        if jq . "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$file_path"
            echo -e "\033[1;32m✓ Repaired JSON file: $file_path\033[0m"
            return 0
        fi
    fi
    
    rm -f "$temp_file"
    return 1
}

# Enhanced API call with retry
send_to_ai_with_retry() {
    local message=$1
    local conv_id=$2
    local context=$3
    local attempt=0
    local backoff=$INITIAL_BACKOFF
    
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        ((attempt++))
        
        # Check network
        if ! ping -c 1 -W 2 api.thinkai.net &>/dev/null; then
            log_error "Network connectivity issue"
            sleep 5
            continue
        fi
        
        # Make API call
        local response=$(timeout 30 curl -s -X POST "${BASE_URL}/chat" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"$message\",\"conversation_id\":\"$conv_id\",\"context\":$context}" 2>&1)
        
        if [[ $? -eq 0 ]] && [[ -n "$response" ]]; then
            if echo "$response" | jq . &>/dev/null; then
                echo "$response"
                return 0
            fi
        fi
        
        echo -e "\033[1;33mRetrying in ${backoff}s... (attempt $attempt/$MAX_RETRIES)\033[0m"
        sleep $backoff
        backoff=$((backoff * 2))
    done
    
    log_error "Failed after $MAX_RETRIES attempts"
    return 1
}

# Backup function
create_backup() {
    local file_path="$1"
    local backup_dir="$CLIII_DIR/backups"
    mkdir -p "$backup_dir"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$backup_dir/$(basename "$file_path").$(date +%Y%m%d_%H%M%S)"
    fi
}

# Enhanced command execution
execute_command_safe() {
    local command=$1
    local working_dir=$2
    
    # Dangerous command check
    if [[ "$command" =~ (rm[[:space:]]+-rf[[:space:]]+/|dd[[:space:]]+if=|mkfs\.) ]]; then
        echo -e "\033[1;31m⚠ Dangerous command detected!\033[0m"
        read -p "Continue? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && return 1
    fi
    
    # Dry run mode
    if [[ $DRY_RUN_MODE == "true" ]]; then
        echo -e "\033[1;36m[DRY RUN] Would execute: $command\033[0m"
        return 0
    fi
    
    # Execute command directly
    if [[ -n "$working_dir" ]]; then
        pushd "$working_dir" > /dev/null 2>&1
    fi
    
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    echo "$output"
    
    if [[ -n "$working_dir" ]]; then
        popd > /dev/null 2>&1
    fi
    
    # Auto-fix common errors
    if [[ $exit_code -ne 0 ]] && [[ $AUTO_FIX_MODE == "true" ]]; then
        case "$command" in
            "npm "*)
                if [[ ! -f "package.json" ]]; then
                    echo -e "\033[1;33mInitializing npm project...\033[0m"
                    npm init -y
                    # Re-execute the original command
                    output=$(eval "$command" 2>&1)
                    exit_code=$?
                    echo "$output"
                fi
                ;;
        esac
    fi
    
    return $exit_code
}

# Show verification steps
show_verification() {
    echo -e "\n\033[1;36m=== How to verify locally ===\033[0m"
    echo "• Check files: ls -la"
    echo "• View content: cat <filename>"
    echo "• Test commands: echo \$?"
    echo "• View logs: cat ~/.cliii/errors.log"
    echo -e "\033[1;36m========================\033[0m\n"
}
EOF

# Inject enhanced functions into int.sh
# Find the line after BASE_URL definition and inject our functions
sed -i '/^BASE_URL=/a\
\
# Source enhanced functions\
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"\
if [[ -f "$SCRIPT_DIR/enhanced_functions.sh" ]]; then\
    source "$SCRIPT_DIR/enhanced_functions.sh"\
fi' int.sh

# Replace send_to_ai calls with enhanced version
sed -i 's/send_to_ai /send_to_ai_with_retry /g' int.sh

# Replace execute_command with safe version
sed -i 's/execute_command(/execute_command_safe(/g' int.sh

# Add verification after operations
sed -i '/echo -e "\\033\[1;32m✓/a\
    [[ "${CLIII_SHOW_VERIFY:-true}" == "true" ]] && show_verification' int.sh

# Add JSON validation before parsing
sed -i '/jq.*"$CONV_DIR/i\
        repair_json "$CONV_DIR/${conv_id}.json" 2>/dev/null' int.sh

# Add backup before file modifications
sed -i '/echo -e "$content" >/i\
            create_backup "$file_path"' int.sh

# Make scripts executable
chmod +x int.sh enhanced_functions.sh

echo "Enhancement complete! New features added:"
echo "• Automatic error recovery with exponential backoff"
echo "• Self-healing JSON repair"
echo "• File operation backups"
echo "• Dangerous command detection"
echo "• Dry-run mode (export CLIII_DRY_RUN=true)"
echo "• Auto-fix mode (export CLIII_AUTO_FIX=true)"
echo "• Verification instructions after operations"
echo ""
echo "To test: ./int.sh"
echo "To see all errors: cat ~/.cliii/errors.log"