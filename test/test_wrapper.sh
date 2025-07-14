#!/bin/bash

# Test wrapper to prevent interactive mode during testing
# Ensures tests run in non-interactive batch mode

# Set non-interactive mode
export CLIII_TEST_MODE=1
export CLIII_NON_INTERACTIVE=1
export PS1=""

# Disable any read prompts
export DEBIAN_FRONTEND=noninteractive

# Source only the functions, not the main execution
source_functions_only() {
    local script="$1"
    
    # Create a temporary file with functions only
    local temp_file="/tmp/functions_only_$$.sh"
    
    # Extract everything except the main execution
    awk '
    BEGIN { in_main = 0 }
    /^# Main execution|^# Start the conversation loop|^while true; do/ { in_main = 1 }
    in_main == 0 { print }
    ' "$script" > "$temp_file"
    
    # Source the functions
    source "$temp_file"
    
    # Clean up
    rm -f "$temp_file"
}

# Export function for use in tests
export -f source_functions_only

# Execute the requested command
exec "$@"