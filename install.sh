#!/bin/bash

# ThinkAI CLI Installation Script

echo "🚀 Installing ThinkAI CLI..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create a symlink in /usr/local/bin
if [[ -w /usr/local/bin ]]; then
    # Create symlink with name 'thinkai'
    sudo ln -sf "$SCRIPT_DIR/int.sh" /usr/local/bin/thinkai
    echo "✅ Created symlink: /usr/local/bin/thinkai"
else
    # Alternative: Add to user's local bin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$SCRIPT_DIR/int.sh" "$HOME/.local/bin/thinkai"
    echo "✅ Created symlink: $HOME/.local/bin/thinkai"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo ""
        echo "⚠️  Add this to your ~/.bashrc or ~/.zshrc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

# Make sure the main script is executable
chmod +x "$SCRIPT_DIR/int.sh"
chmod +x "$SCRIPT_DIR/enhanced_functions.sh" 2>/dev/null || true

echo ""
echo "✅ Installation complete!"
echo ""
echo "📝 Usage: Type 'thinkai' in your terminal to start the CLI"
echo ""
echo "🤖 ThinkAI CLI leverages the ThinkAI API to:"
echo "   • Automatically create and modify files based on your requests"
echo "   • Execute commands intelligently"
echo "   • Maintain conversation context"
echo "   • Analyze codebases"
echo ""
echo "Try it now: thinkai"