#!/bin/bash

echo "=== Testing Fixed ThinkAI CLI with Real API ==="
echo ""

# Clean test directory
rm -rf final_test
mkdir -p final_test
cd final_test

# Test creating a hello.js file
echo "Test: Creating hello.js file that prints 'Hello from ThinkAI'"
echo ""

# Run the CLI with a simple request
echo "create a simple hello.js file that prints Hello from ThinkAI" | CLIII_AGENTIC_MODE=true timeout 30 ../int.sh

echo ""
echo "=== Results ==="

# Check if the file was created
if ls *.js 2>/dev/null; then
    echo "✅ JavaScript file(s) created:"
    for f in *.js; do
        echo ""
        echo "📄 File: $f"
        echo "Content:"
        cat "$f"
        echo ""
        echo "Running: node $f"
        node "$f" 2>&1 || echo "Failed to run"
    done
else
    echo "❌ No JavaScript files created"
fi

echo ""
echo "Directory contents:"
ls -la

cd ..
echo ""
echo "=== Test Complete ==="