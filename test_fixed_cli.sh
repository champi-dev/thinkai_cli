#!/bin/bash

echo "=== Testing Fixed ThinkAI CLI ==="
echo ""

# Clean test directory
rm -rf test_output
mkdir -p test_output
cd test_output

# Test 1: Create hello.js file
echo "Test 1: Creating hello.js file"
echo "create a hello.js file that prints Hello from ThinkAI" | CLIII_AGENTIC_MODE=true timeout 30 ../int.sh

echo ""
echo "Results:"
if [[ -f hello.js ]]; then
    echo "✅ hello.js created successfully!"
    echo "Content:"
    cat hello.js
    echo ""
    echo "Running the file:"
    node hello.js
else
    echo "❌ hello.js not created"
    ls -la
fi

echo ""
echo "=== Test Complete ==="
cd ..