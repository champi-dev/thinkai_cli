#!/bin/bash

echo "=== Final Test of Fixed ThinkAI CLI ==="
echo ""

# Clean test directory
rm -rf final_test_output
mkdir -p final_test_output
cd final_test_output

echo "Test 1: Create a Node.js server"
echo "build a simple node.js server that responds with Hello World" | ../int.sh
echo ""
echo "Files created:"
ls -la *.js 2>/dev/null || echo "No .js files created"
echo ""

if [[ -f app.js ]]; then
    echo "Content of app.js:"
    head -20 app.js
    echo ""
fi

echo "---"
echo "Test 2: Create a Python script"
echo "create a python script that prints the current date" | ../int.sh
echo ""
echo "Python files created:"
ls -la *.py 2>/dev/null || echo "No .py files created"
echo ""

echo "---"
echo "Test 3: Command execution"
echo "create package.json for a node project and then run npm install express" | ../int.sh
echo ""
echo "Package.json content:"
cat package.json 2>/dev/null || echo "No package.json created"
echo ""

cd ..
echo "=== All Tests Complete ==="