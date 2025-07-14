#!/bin/bash

# Test script to verify ThinkAI CLI coding capabilities

echo "Testing ThinkAI CLI coding functionality..."
echo ""

# Test 1: Simple code generation
echo "Test 1: Asking to create a simple Node.js script"
echo "build a simple node.js script" | timeout 30 ./int.sh | tee test_output1.txt
echo ""
echo "Files created:"
ls -la *.js 2>/dev/null || echo "No .js files created"
echo ""

# Test 2: Server creation
echo "Test 2: Asking to create a Node.js server"
echo "write a simple node.js server" | timeout 30 ./int.sh | tee test_output2.txt
echo ""
echo "Files after server request:"
ls -la *.js 2>/dev/null || echo "No .js files created"
echo ""

# Test 3: Command execution
echo "Test 3: Testing command execution"
echo "create a file test.txt with content hello world" | timeout 30 ./int.sh | tee test_output3.txt
echo ""
echo "Checking if test.txt was created:"
ls -la test.txt 2>/dev/null && cat test.txt 2>/dev/null || echo "test.txt not created"
echo ""

echo "Test complete. Check the output files for detailed responses."