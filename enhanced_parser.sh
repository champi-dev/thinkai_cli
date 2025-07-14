#!/bin/bash

# Enhanced Parser for ThinkAI CLI
# This module provides exponentially smarter parsing capabilities

# Advanced regex patterns for code detection
declare -A CODE_PATTERNS=(
    # File creation patterns
    ["file_create"]='(create|make|write|save|generate|build)\s+(a\s+)?(new\s+)?(\w+\.[\w]+)'
    ["file_save_as"]='save\s+(this\s+)?(as|to)\s+(\w+\.[\w]+)'
    ["file_named"]='(file\s+)?named\s+(\w+\.[\w]+)'
    ["file_called"]='(file\s+)?called\s+(\w+\.[\w]+)'
    
    # Command patterns
    ["cmd_run"]='(run|execute|exec):\s*`([^`]+)`'
    ["cmd_shell"]='^\$\s+(.+)$'
    ["cmd_npm"]='npm\s+(install|run|test|start)\s+[\w-]+'
    ["cmd_git"]='git\s+(add|commit|push|pull|clone)\s+.+'
    ["cmd_explicit"]='(command|cmd):\s*`([^`]+)`'
    
    # Code block patterns with language detection
    ["code_start"]='```(\w+)?'
    ["code_end"]='```'
    ["code_inline"]='`([^`]+)`'
    
    # Project structure patterns
    ["folder_create"]='(create|make)\s+(folder|directory|dir)\s+(\w+)'
    ["project_init"]='(initialize|init|create)\s+(a\s+)?(\w+)\s+project'
)

# Language to file extension mapping
declare -A LANG_EXTENSIONS=(
    ["javascript"]="js"
    ["js"]="js"
    ["typescript"]="ts"
    ["ts"]="ts"
    ["python"]="py"
    ["py"]="py"
    ["bash"]="sh"
    ["sh"]="sh"
    ["shell"]="sh"
    ["json"]="json"
    ["html"]="html"
    ["css"]="css"
    ["yaml"]="yaml"
    ["yml"]="yml"
    ["sql"]="sql"
    ["go"]="go"
    ["rust"]="rs"
    ["java"]="java"
    ["cpp"]="cpp"
    ["c"]="c"
)

# Enhanced operation extraction
extract_operations_smart() {
    local response_text=$1
    local operations=()
    local current_file=""
    local in_code_block=false
    local code_content=""
    local code_lang=""
    local line_num=0
    
    # Pre-process to find all mentioned files
    local mentioned_files=()
    while IFS= read -r line; do
        # Extract file mentions using all patterns
        for pattern in "${CODE_PATTERNS[@]}"; do
            if [[ "$line" =~ $pattern ]]; then
                local matches=("${BASH_REMATCH[@]}")
                for match in "${matches[@]}"; do
                    if [[ "$match" =~ \.[\w]+ ]]; then
                        mentioned_files+=("$match")
                    fi
                done
            fi
        done
    done <<< "$response_text"
    
    # Process line by line for code blocks and commands
    while IFS= read -r line; do
        ((line_num++))
        
        # Check for code block start
        if [[ "$line" =~ ^${CODE_PATTERNS["code_start"]}$ ]]; then
            if [[ ! "$in_code_block" == true ]]; then
                in_code_block=true
                code_lang="${BASH_REMATCH[1]:-plaintext}"
                code_content=""
                
                # Try to associate with most recently mentioned file
                if [[ ${#mentioned_files[@]} -gt 0 ]]; then
                    current_file="${mentioned_files[-1]}"
                else
                    # Generate filename from language
                    local ext="${LANG_EXTENSIONS[$code_lang]:-txt}"
                    current_file="code.$ext"
                fi
                continue
            fi
        fi
        
        # Check for code block end
        if [[ "$line" =~ ^${CODE_PATTERNS["code_end"]}$ ]] && [[ "$in_code_block" == true ]]; then
            in_code_block=false
            
            # Create file operation
            if [[ -n "$code_content" ]]; then
                operations+=("$(create_file_operation "$current_file" "$code_content")")
            fi
            continue
        fi
        
        # Accumulate code block content
        if [[ "$in_code_block" == true ]]; then
            [[ -n "$code_content" ]] && code_content+=$'\n'
            code_content+="$line"
            continue
        fi
        
        # Check for commands outside code blocks
        check_for_commands "$line" operations
    done <<< "$response_text"
    
    # Output operations as JSON array
    printf '%s\n' "${operations[@]}" | jq -s '.'
}

# Create file operation JSON
create_file_operation() {
    local filepath=$1
    local content=$2
    
    jq -n \
        --arg path "$filepath" \
        --arg content "$content" \
        '{
            type: "file",
            operation: "write",
            path: $path,
            content: $content
        }'
}

# Check for command patterns
check_for_commands() {
    local line=$1
    local -n ops_ref=$2
    
    # Shell command format: $ command
    if [[ "$line" =~ ${CODE_PATTERNS["cmd_shell"]} ]]; then
        local cmd="${BASH_REMATCH[1]}"
        ops_ref+=("$(create_command_operation "$cmd")")
        return
    fi
    
    # Run/execute format
    if [[ "$line" =~ ${CODE_PATTERNS["cmd_run"]} ]]; then
        local cmd="${BASH_REMATCH[2]}"
        ops_ref+=("$(create_command_operation "$cmd")")
        return
    fi
    
    # Explicit command format
    if [[ "$line" =~ ${CODE_PATTERNS["cmd_explicit"]} ]]; then
        local cmd="${BASH_REMATCH[2]}"
        ops_ref+=("$(create_command_operation "$cmd")")
        return
    fi
    
    # NPM commands
    if [[ "$line" =~ ${CODE_PATTERNS["cmd_npm"]} ]]; then
        ops_ref+=("$(create_command_operation "${BASH_REMATCH[0]}")")
        return
    fi
}

# Create command operation JSON
create_command_operation() {
    local cmd=$1
    
    jq -n \
        --arg command "$cmd" \
        '{
            type: "command",
            command: $command
        }'
}

# Context-aware parsing
parse_with_context() {
    local response=$1
    local context=$2
    
    # Extract project type from context
    local project_type=""
    if [[ -f "package.json" ]]; then
        project_type="nodejs"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        project_type="python"
    elif [[ -f "go.mod" ]]; then
        project_type="go"
    fi
    
    # Apply context-specific enhancements
    case "$project_type" in
        "nodejs")
            # Add npm-specific patterns
            response=$(enhance_nodejs_response "$response")
            ;;
        "python")
            # Add pip-specific patterns
            response=$(enhance_python_response "$response")
            ;;
    esac
    
    extract_operations_smart "$response"
}

# Enhance Node.js responses
enhance_nodejs_response() {
    local response=$1
    
    # Auto-detect package installation needs
    if [[ "$response" =~ import.*from.*[\'\"]([\w-]+)[\'\"] ]] || 
       [[ "$response" =~ require\([\'\"]([\w-]+)[\'\"]\) ]]; then
        local package="${BASH_REMATCH[1]}"
        if [[ ! "$package" =~ ^\./ ]] && [[ ! -d "node_modules/$package" ]]; then
            response+="\n\n\$ npm install $package"
        fi
    fi
    
    echo "$response"
}

# Enhance Python responses
enhance_python_response() {
    local response=$1
    
    # Auto-detect pip installation needs
    if [[ "$response" =~ import\s+([\w-]+) ]] || 
       [[ "$response" =~ from\s+([\w-]+)\s+import ]]; then
        local package="${BASH_REMATCH[1]}"
        # Check if it's not a standard library module
        if ! python3 -c "import $package" 2>/dev/null; then
            response+="\n\n\$ pip install $package"
        fi
    fi
    
    echo "$response"
}

# Progressive parsing with memory
declare -A PARSING_MEMORY

parse_progressive() {
    local response=$1
    local conv_id=$2
    
    # Load previous context
    local prev_files="${PARSING_MEMORY["$conv_id:files"]:-}"
    local prev_commands="${PARSING_MEMORY["$conv_id:commands"]:-}"
    
    # Parse current response
    local operations=$(extract_operations_smart "$response")
    
    # Update memory
    local new_files=$(echo "$operations" | jq -r '.[] | select(.type=="file") | .path')
    local new_commands=$(echo "$operations" | jq -r '.[] | select(.type=="command") | .command')
    
    PARSING_MEMORY["$conv_id:files"]="$prev_files $new_files"
    PARSING_MEMORY["$conv_id:commands"]="$prev_commands $new_commands"
    
    # Add context hints for progressive coding
    if [[ -n "$prev_files" ]]; then
        operations=$(echo "$operations" | jq --arg context "$prev_files" '. + [{type: "context", previous_files: ($context | split(" "))}]')
    fi
    
    echo "$operations"
}

# Intelligent command validation
validate_command_smart() {
    local cmd=$1
    
    # Check for dangerous patterns
    local dangerous_patterns=(
        'rm\s+-rf\s+/'
        'dd\s+if=/dev/(zero|random)'
        ':\(\)\{\s*:\|\s*:\&\s*\};'  # Fork bomb
        'mkfs\.'
        '>\s*/dev/sd[a-z]'
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$cmd" =~ $pattern ]]; then
            return 1
        fi
    done
    
    return 0
}

# Export functions for use in main script
export -f extract_operations_smart
export -f parse_with_context
export -f parse_progressive
export -f validate_command_smart