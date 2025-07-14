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
    local system_prompt=${4:-}  # Optional system prompt
    local attempt=0
    local backoff=$INITIAL_BACKOFF
    
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        ((attempt++))
        
        # Check network
        if ! ping -c 1 -W 2 thinkai.lat &>/dev/null; then
            log_error "Network connectivity issue"
            sleep 5
            continue
        fi
        
        # Build request body
        local request_body="{\"message\":\"$message\",\"conversation_id\":\"$conv_id\",\"context\":$context"
        if [[ -n "$system_prompt" ]]; then
            request_body+=",\"system_prompt\":$system_prompt"
        fi
        request_body+="}"
        
        # Make API call
        local response=$(timeout 30 curl -s -X POST "${BASE_URL}/chat" \
            -H "Content-Type: application/json" \
            -d "$request_body" 2>&1)
        
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

# Streaming API call with retry and real-time output
send_to_ai_streaming() {
    local message=$1
    local conv_id=$2
    local context=$3
    local system_prompt=${4:-}  # Optional system prompt
    local attempt=0
    local backoff=$INITIAL_BACKOFF
    local accumulated_response=""
    local temp_response_file=$(mktemp)
    
    # Clean up on exit
    trap "rm -f $temp_response_file" EXIT
    
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        ((attempt++))
        
        # Check network
        if ! ping -c 1 -W 2 thinkai.lat &>/dev/null; then
            log_error "Network connectivity issue"
            sleep 5
            continue
        fi
        
        # Clear temp file
        > "$temp_response_file"
        
        # Build request body
        local request_body="{\\\"message\\\":\\\"$message\\\",\\\"conversation_id\\\":\\\"$conv_id\\\",\\\"context\\\":$context"
        if [[ -n "$system_prompt" ]]; then
            request_body+=",\\\"system_prompt\\\":$system_prompt"
        fi
        request_body+="}"
        
        # Make streaming API call
        # Using curl with -N flag to disable buffering for real-time streaming
        local curl_cmd="curl -N -s -X POST \"${BASE_URL}/chat/stream\" \
            -H \"Content-Type: application/json\" \
            -H \"Accept: text/event-stream\" \
            -d \"$request_body\""
        
        # Show streaming indicator
        echo -ne "\033[1;36m🔄 Streaming: \033[0m"
        
        # Start curl in background and capture its PID
        local chunk_count=0
        eval "$curl_cmd" 2>&1 | while IFS= read -r line; do
            # Process SSE data
            if [[ "$line" =~ ^data:\ (.+)$ ]]; then
                local data="${BASH_REMATCH[1]}"
                
                # Skip [DONE] message
                if [[ "$data" == "[DONE]" ]]; then
                    echo -ne "\r\033[K" # Clear the streaming line
                    break
                fi
                
                # Try to parse JSON data and display chunk
                local chunk_text=$(echo "$data" | jq -r '.content // .chunk // .text // empty' 2>/dev/null)
                if [[ -n "$chunk_text" ]]; then
                    # Display streaming text in real-time
                    echo -ne "$chunk_text"
                    # Accumulate response for final processing
                    echo "$data" >> "$temp_response_file"
                    ((chunk_count++))
                fi
            elif [[ "$line" =~ ^event:\ (.+)$ ]]; then
                # Handle SSE events if needed
                local event="${BASH_REMATCH[1]}"
                if [[ "$event" == "error" ]]; then
                    echo -ne "\n\033[1;31m⚠️  Stream error\033[0m\n"
                    break
                fi
            fi
        done
        
        # Add newline after streaming completes
        [[ $chunk_count -gt 0 ]] && echo
        
        # Check if we got valid response
        if [[ -s "$temp_response_file" ]]; then
            # Construct final response object from accumulated chunks
            accumulated_response=$(jq -s '{
                response: (map(.content // .chunk // .text // "") | join("")),
                conversation_id: (.[0].conversation_id // "'"$conv_id"'"),
                metadata: (.[0].metadata // {})
            }' "$temp_response_file" 2>/dev/null)
            
            if [[ -n "$accumulated_response" ]] && [[ "$accumulated_response" != "null" ]]; then
                echo "$accumulated_response"
                rm -f "$temp_response_file"
                return 0
            fi
        fi
        
        # Fallback to non-streaming endpoint if streaming fails
        if [[ $attempt -eq 1 ]]; then
            echo -e "\033[1;33mStreaming endpoint unavailable, falling back to standard API...\033[0m" >&2
            rm -f "$temp_response_file"
            send_to_ai_with_retry "$message" "$conv_id" "$context" "$system_prompt"
            return $?
        fi
        
        echo -e "\033[1;33mRetrying in ${backoff}s... (attempt $attempt/$MAX_RETRIES)\033[0m" >&2
        sleep $backoff
        backoff=$((backoff * 2))
    done
    
    rm -f "$temp_response_file"
    log_error "Streaming API failed after $MAX_RETRIES attempts"
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

# Enhanced command execution with progress
execute_command_safe() {
    local command=$1
    local working_dir=$2
    
    # Show command being executed
    echo -e "\n\033[1;34m📦 Executing: \033[0m$command"
    
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
    
    # Show working directory if specified
    if [[ -n "$working_dir" ]]; then
        echo -e "\033[1;90m📁 Working directory: $working_dir\033[0m"
        pushd "$working_dir" > /dev/null 2>&1
    fi
    
    # Show spinner while command runs
    local output_file=$(mktemp)
    (
        eval "$command" > "$output_file" 2>&1
        echo $? > "${output_file}.exit"
    ) &
    local cmd_pid=$!
    
    # Spinner animation
    local spin_chars="⠀⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋"
    local i=0
    while kill -0 $cmd_pid 2>/dev/null; do
        printf "\r\033[1;36m%s Processing...\033[0m" "${spin_chars:i:1}"
        i=$(((i+1) % ${#spin_chars}))
        sleep 0.1
    done
    printf "\r\033[K" # Clear spinner line
    
    # Get output and exit code
    local output=$(cat "$output_file")
    local exit_code=$(cat "${output_file}.exit")
    rm -f "$output_file" "${output_file}.exit"
    
    # Show output with proper formatting
    if [[ -n "$output" ]]; then
        echo -e "\033[1;90m┌ Output:\033[0m"
        echo "$output" | sed 's/^/\033[1;90m│\033[0m /'
        echo -e "\033[1;90m└──────\033[0m"
    fi
    
    # Show status
    if [[ $exit_code -eq 0 ]]; then
        echo -e "\033[1;32m✅ Command completed successfully\033[0m"
    else
        echo -e "\033[1;31m❌ Command failed with exit code: $exit_code\033[0m"
        
        # AI-powered error analysis if available
        if type -t analyze_error_with_ai &>/dev/null && [[ -n "$output" ]]; then
            # Get conversation ID from parent scope or use temp
            local conv_id="${current_conversation:-temp_error_analysis}"
            analyze_error_with_ai "$output" "$command" "$conv_id"
        fi
    fi
    
    if [[ -n "$working_dir" ]]; then
        popd > /dev/null 2>&1
    fi
    
    # Auto-fix common errors
    if [[ $exit_code -ne 0 ]] && [[ $AUTO_FIX_MODE == "true" ]]; then
        case "$command" in
            "npm "*)
                if [[ ! -f "package.json" ]]; then
                    echo -e "\033[1;33m🔧 Auto-fixing: Initializing npm project...\033[0m"
                    npm init -y
                    # Re-execute the original command
                    echo -e "\033[1;34m🔁 Retrying command...\033[0m"
                    execute_command_safe "$command" "$working_dir"
                    return $?
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

# Progress indicator function
show_progress() {
    local step=$1
    local total=$2
    local description=$3
    local percent=$((step * 100 / total))
    local bar_length=30
    local filled=$((bar_length * step / total))
    
    # Build progress bar
    local bar="["
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=filled; i<bar_length; i++)); do
        bar+="░"
    done
    bar+="]"
    
    # Print progress with description
    echo -ne "\r\033[1;34m$bar $percent% \033[1;37m$description\033[0m\033[K"
    
    # New line when complete
    if [[ $step -eq $total ]]; then
        echo
    fi
}

# Enhanced operation executor with progress
execute_operations_with_progress() {
    local operations=$1
    local total_ops=$(echo "$operations" | jq 'length' 2>/dev/null || echo 0)
    local current_op=0
    
    if [[ $total_ops -eq 0 ]]; then
        return 0
    fi
    
    echo -e "\n\033[1;36m📋 Executing $total_ops operations...\033[0m"
    
    # Process each operation
    echo "$operations" | jq -c '.[]' | while IFS= read -r op; do
        ((current_op++))
        
        local op_type=$(echo "$op" | jq -r '.type // "unknown"')
        local op_desc=""
        
        case "$op_type" in
            "file")
                local file_op=$(echo "$op" | jq -r '.operation // "unknown"')
                local file_path=$(echo "$op" | jq -r '.path // "unknown"')
                op_desc="$file_op $(basename "$file_path")"
                ;;
            "command")
                local cmd=$(echo "$op" | jq -r '.command // "unknown"')
                op_desc="Running: $cmd"
                ;;
            *)
                op_desc="Processing $op_type operation"
                ;;
        esac
        
        # Show progress
        show_progress $current_op $total_ops "$op_desc"
        
        # Small delay to make progress visible
        sleep 0.1
    done
    
    echo -e "\033[1;32m✅ All operations completed!\033[0m\n"
}

# AI-powered smart command suggestions
get_smart_suggestions() {
    local user_input="$1"
    local context="$2"
    local conv_id="$3"
    
    # Quick AI query for command suggestions
    local suggestion_prompt="Given the user wants to: '$user_input', suggest the best shell command to accomplish this. Reply with ONLY the command, no explanation."
    
    # Use streaming API for quick suggestions
    local suggestion=$(send_to_ai_streaming "$suggestion_prompt" "$conv_id" "$context" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
    
    if [[ -n "$suggestion" ]] && [[ "$suggestion" != "null" ]]; then
        echo "$suggestion"
        return 0
    fi
    return 1
}

# AI-powered error analysis
analyze_error_with_ai() {
    local error_output="$1"
    local failed_command="$2"
    local conv_id="$3"
    
    echo -e "\n\033[1;33m🤔 Analyzing error with AI...\033[0m"
    
    local analysis_prompt="The command '$failed_command' failed with this error:\n\n$error_output\n\nProvide a brief explanation of what went wrong and suggest a fix. Be concise."
    
    # Use streaming for real-time analysis
    local analysis=$(send_to_ai_streaming "$analysis_prompt" "$conv_id" "[]" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
    
    if [[ -n "$analysis" ]] && [[ "$analysis" != "null" ]]; then
        echo -e "\n\033[1;36m💡 AI Analysis:\033[0m"
        echo "$analysis" | fold -s -w 80
        return 0
    fi
    return 1
}

# Smart auto-completion using AI
smart_autocomplete() {
    local partial_cmd="$1"
    local conv_id="$2"
    
    if [[ ${#partial_cmd} -lt 3 ]]; then
        return 1  # Too short to autocomplete
    fi
    
    local complete_prompt="Complete this shell command: '$partial_cmd'. Reply with ONLY the completed command, nothing else."
    
    local completion=$(send_to_ai_streaming "$complete_prompt" "$conv_id" "[]" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
    
    if [[ -n "$completion" ]] && [[ "$completion" != "null" ]] && [[ "$completion" != "$partial_cmd"* ]]; then
        echo "$completion"
        return 0
    fi
    return 1
}

# Intelligent command validation
validate_command_with_ai() {
    local command="$1"
    local conv_id="$2"
    
    local validate_prompt="Is this a safe and valid shell command: '$command'? Reply with YES if safe, or NO followed by a brief reason if not."
    
    local validation=$(send_to_ai_streaming "$validate_prompt" "$conv_id" "[]" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
    
    if [[ "$validation" =~ ^YES ]]; then
        return 0
    elif [[ "$validation" =~ ^NO ]]; then
        echo -e "\033[1;31m⚠️  AI Warning: ${validation#NO }\033[0m"
        return 1
    fi
    return 2  # Uncertain
}

# Context-aware command enhancement
enhance_command_with_context() {
    local command="$1"
    local working_dir="$2"
    local conv_id="$3"
    
    # Analyze current directory context
    local dir_context=""
    if [[ -f "package.json" ]]; then
        dir_context="Node.js project"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        dir_context="Python project"
    elif [[ -f "Gemfile" ]]; then
        dir_context="Ruby project"
    elif [[ -f "go.mod" ]]; then
        dir_context="Go project"
    elif [[ -d ".git" ]]; then
        dir_context="Git repository"
    fi
    
    if [[ -n "$dir_context" ]]; then
        local enhance_prompt="In a $dir_context, the user wants to run: '$command'. Suggest an enhanced or corrected version if needed. Reply with ONLY the command."
        
        local enhanced=$(send_to_ai_streaming "$enhance_prompt" "$conv_id" "[]" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
        
        if [[ -n "$enhanced" ]] && [[ "$enhanced" != "null" ]] && [[ "$enhanced" != "$command" ]]; then
            echo -e "\033[1;36m💡 AI suggests: \033[0m$enhanced"
            read -p "Use suggested command? (y/n): " use_suggestion
            if [[ "$use_suggestion" == "y" ]]; then
                echo "$enhanced"
                return 0
            fi
        fi
    fi
    
    echo "$command"
    return 1
}

# Smart project initialization
smart_project_init() {
    local project_type="$1"
    local project_name="$2"
    local conv_id="$3"
    
    echo -e "\033[1;36m🤖 AI-powered project initialization...\033[0m"
    
    local init_prompt="Create a complete initialization script for a $project_type project named '$project_name'. Include all necessary files, dependencies, and folder structure. Format as operations JSON."
    
    # Use streaming for real-time project generation
    local operations=$(send_to_ai_streaming "$init_prompt" "$conv_id" "[]" 2>/dev/null | jq -r '.response // empty' 2>/dev/null)
    
    if [[ -n "$operations" ]] && [[ "$operations" != "null" ]]; then
        # Parse and execute operations
        local parsed_ops=$(parse_ai_response_to_operations "$operations")
        if [[ -n "$parsed_ops" ]]; then
            execute_operations_with_progress "$parsed_ops"
            return 0
        fi
    fi
    return 1
}
