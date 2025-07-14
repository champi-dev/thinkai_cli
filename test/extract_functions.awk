#!/usr/bin/awk -f

# Extract only function definitions from bash scripts
# Skips main execution, readonly variables, and other problematic constructs

BEGIN {
    in_function = 0
    in_main = 0
    brace_count = 0
}

# Skip main execution sections
/^# Main execution|^# Start the conversation loop|^while true; do|^# Execute main if/ {
    in_main = 1
}

# Skip readonly declarations
/^readonly / {
    next
}

# Skip SCRIPT_DIR assignments that might conflict
/^SCRIPT_DIR=/ {
    next
}

# Track function definitions
/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ {
    if (!in_main) {
        in_function = 1
        brace_count = 0
        print
        next
    }
}

# Track braces in functions
in_function {
    print
    
    # Count braces
    gsub(/[^{]/, "", $0)
    brace_count += length($0)
    
    gsub(/[^}]/, "", $0)
    brace_count -= length($0)
    
    # End of function
    if (brace_count <= 0) {
        in_function = 0
        print ""
    }
    next
}

# Include necessary setup that's not in main
!in_main && !in_function && !/^#!/ {
    # Include variable declarations and sourcing
    if (/^BASE_URL=/ || /^CONV_DIR=/ || /^CURRENT_CONV_FILE=/ || /^CONTEXT_DIR=/ || /^CODEBASE_INDEX=/) {
        print
    }
}

END {
    # Add any cleanup needed
}