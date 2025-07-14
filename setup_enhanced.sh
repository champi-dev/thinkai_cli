#!/bin/bash

# Quick setup script for ThinkAI CLI Enhanced Features
# Run this to instantly enable all automatic recovery and self-healing features

echo "🚀 Setting up ThinkAI CLI Enhanced Features..."

# Check if int.sh exists
if [[ ! -f "int.sh" ]]; then
    echo "❌ Error: int.sh not found. Please run this from the ThinkAI CLI directory."
    exit 1
fi

# Apply enhancements
echo "📦 Applying enhancements..."
chmod +x enhance_cli.sh
./enhance_cli.sh

# Run tests
echo -e "\n🧪 Running tests..."
chmod +x test_enhanced_features.sh
if ./test_enhanced_features.sh; then
    echo -e "\n✅ All tests passed!"
else
    echo -e "\n⚠️  Some tests failed, but enhancements are still applied."
fi

# Show usage
echo -e "\n📖 Enhanced ThinkAI CLI is ready!"
echo -e "\nNew features enabled:"
echo "  • Automatic error recovery with retries"
echo "  • Self-healing JSON repair"
echo "  • File operation backups"
echo "  • Dry-run mode for safety"
echo "  • Auto-fix for common errors"
echo "  • Verification steps after operations"

echo -e "\n🎯 Quick start:"
echo "  ./int.sh                    # Run enhanced CLI"
echo "  ./demo_enhanced_features.sh # See features in action"
echo "  cat ENHANCED_FEATURES.md    # Read full documentation"

echo -e "\n🔧 Environment variables:"
echo "  export CLIII_DRY_RUN=true   # Preview operations without executing"
echo "  export CLIII_AUTO_FIX=true  # Automatically fix common errors"
echo "  export CLIII_SHOW_VERIFY=true # Show verification steps"

echo -e "\n✨ Happy coding with enhanced ThinkAI CLI!"