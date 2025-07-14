#!/bin/bash

echo "=== Testing Fixed ThinkAI CLI ==="
echo ""

# Clean test directory
rm -rf test_fixed_output
mkdir -p test_fixed_output
cd test_fixed_output

# Test the fixed CLI
echo "Testing: create a hello.js file that prints Hello from ThinkAI"
echo "create a hello.js file that prints Hello from ThinkAI" | ../int_fixed.sh

echo ""
echo "=== Results ==="

# Check results
if [[ -f hello.js ]]; then
    echo "✅ SUCCESS! hello.js was created"
    echo ""
    echo "📄 File contents:"
    cat hello.js
    echo ""
    echo "🚀 Running the file:"
    node hello.js
else
    echo "❌ File not created. Checking what was created:"
    ls -la
fi

cd ..
echo ""
echo "=== Test Complete ==="