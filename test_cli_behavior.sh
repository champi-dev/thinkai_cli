#!/bin/bash

# Test script to verify CLI behavior

echo "=== Testing ThinkAI CLI File Operations and Command Execution ==="
echo ""

# Test 1: Test file write operation
echo "Test 1: Testing file write operation..."
echo 'write a test file called test_output.txt with content "Hello from CLI"' | ./int.sh
if [[ -f test_output.txt ]]; then
    echo "✅ File created successfully"
    cat test_output.txt
else
    echo "❌ File write failed"
fi
echo ""

# Test 2: Test command execution
echo "Test 2: Testing command execution..."
echo 'run the command: echo "Command executed successfully"' | ./int.sh
echo ""

# Test 3: Test JSON response handling
echo "Test 3: Testing direct JSON response..."
# Simulate a JSON response with operations
test_response='{
  "response": "I will create a test file",
  "operations": [
    {
      "type": "file",
      "operation": "write",
      "path": "test_json.txt",
      "content": "JSON operation test"
    },
    {
      "type": "command",
      "command": "ls -la test_json.txt"
    }
  ]
}'

# Clean up
rm -f test_output.txt test_json.txt

echo ""
echo "=== Test Complete ==="