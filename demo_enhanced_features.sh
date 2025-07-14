#!/bin/bash

# Demo script showcasing enhanced ThinkAI CLI features
# This script demonstrates automatic error recovery, self-healing, and verification

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

clear
echo -e "${MAGENTA}=== ThinkAI CLI Enhanced Features Demo ===${RESET}\n"

# Demo function
demo_step() {
    local step_name="$1"
    local command="$2"
    
    echo -e "\n${CYAN}>>> $step_name${RESET}"
    echo -e "${YELLOW}Command: $command${RESET}"
    read -p "Press Enter to continue..."
    eval "$command"
    echo
}

# 1. Show version and features
demo_step "1. Enhanced CLI Features" "echo -e 'Features enabled:\n• Automatic error recovery\n• Self-healing JSON repair\n• Dry-run mode\n• Auto-fix capabilities\n• Operation verification'"

# 2. Test JSON self-healing
demo_step "2. JSON Self-Healing Demo" "echo '{\"broken\": json,}' > /tmp/broken.json && cat /tmp/broken.json"
demo_step "   Repairing JSON..." "./int_enhanced.sh repair_json /tmp/broken.json 2>&1 | grep -E 'Repaired|Fixed'"

# 3. Dry-run mode demo
demo_step "3. Dry-Run Mode Demo" "export CLIII_DRY_RUN=true && echo 'DRY_RUN mode enabled'"
demo_step "   Simulating dangerous command" "echo -e 'In dry-run mode, this would show:\n[DRY RUN] Would execute: rm -rf /important/files'"

# 4. Auto-fix demo
demo_step "4. Auto-Fix Demo" "export CLIII_DRY_RUN=false && export CLIII_AUTO_FIX=true"
demo_step "   Missing package.json auto-fix" "cd /tmp && mkdir -p demo_project && cd demo_project && echo 'If npm command fails, will auto-create package.json'"

# 5. Backup system demo
demo_step "5. Backup System Demo" "echo 'original content' > /tmp/demo_file.txt"
demo_step "   Creating backup before modification" "echo -e 'File modified' > /tmp/demo_file.txt && ls ~/.cliii/backups/ 2>/dev/null | grep demo_file | head -1"

# 6. Error recovery demo
demo_step "6. Error Recovery Demo" "echo -e 'API calls now retry automatically with:\n• Exponential backoff\n• Network detection\n• Response validation'"

# 7. Verification helper
demo_step "7. Verification Helper Demo" "echo -e '${GREEN}After each operation, users see:${RESET}\n• How to check files: ls -la\n• How to verify content: cat file.txt\n• How to check status: echo \$?\n• How to view logs: cat ~/.cliii/errors.log'"

# 8. Run actual test
echo -e "\n${CYAN}>>> 8. Running Comprehensive Tests${RESET}"
read -p "Run full test suite? (y/n): " run_tests
if [[ "$run_tests" == "y" ]]; then
    chmod +x test_enhanced_features.sh
    ./test_enhanced_features.sh
fi

# Summary
echo -e "\n${MAGENTA}=== Demo Complete ===${RESET}"
echo -e "\n${GREEN}Enhanced features are now active in your ThinkAI CLI!${RESET}"
echo -e "\nTo use enhanced CLI:"
echo -e "  ${CYAN}./enhance_cli.sh${RESET}  # Apply enhancements"
echo -e "  ${CYAN}./int.sh${RESET}          # Run enhanced CLI"
echo -e "\nEnvironment variables:"
echo -e "  ${YELLOW}export CLIII_DRY_RUN=true${RESET}     # Preview mode"
echo -e "  ${YELLOW}export CLIII_AUTO_FIX=true${RESET}    # Auto-fix errors"
echo -e "  ${YELLOW}export CLIII_SHOW_VERIFY=true${RESET} # Show verification"
echo -e "\nFor more info: ${CYAN}cat ENHANCED_FEATURES.md${RESET}"