#!/bin/bash

# Full test of the CLI to verify agentic mode functionality

echo "=== Testing ThinkAI CLI Full Flow ==="
echo ""

# Create a test directory
TEST_DIR="test_cli_output"
rm -rf $TEST_DIR
mkdir -p $TEST_DIR
cd $TEST_DIR

# Test 1: Simple file creation test
echo "Test 1: Testing file creation with code block"
echo ""

# Create an input that simulates what the AI would return
cat > test_input.txt << 'EOF'
I'll create a simple hello world script for you:

```javascript
console.log('Hello from ThinkAI CLI!');
console.log('This file was created automatically.');
```

This script will print a greeting message.
EOF

# Test the CLI with this input
echo "Testing with: 'create a hello world script'"
CLIII_AGENTIC_MODE=true timeout 5 ../int.sh < test_input.txt > output1.log 2>&1 || true

# Check if file was created
echo ""
if ls *.js 2>/dev/null; then
    echo "✅ JavaScript file created:"
    ls -la *.js
    echo "Content:"
    cat *.js
else
    echo "❌ No JavaScript file created"
    echo "CLI output:"
    cat output1.log | tail -20
fi

echo ""
echo "=== Test 2: Command execution test ==="
echo ""

# Create another test input with commands
cat > test_input2.txt << 'EOF'
Let me list the files in the current directory:

`ls -la`

And create a test file:

`echo "Test file content" > test.txt`
EOF

# Test command execution
echo "Testing command execution..."
CLIII_AGENTIC_MODE=true timeout 5 ../int.sh < test_input2.txt > output2.log 2>&1 || true

# Check if test.txt was created
if [[ -f test.txt ]]; then
    echo "✅ Command executed successfully"
    echo "test.txt content: $(cat test.txt)"
else
    echo "❌ Command not executed"
    echo "CLI output:"
    cat output2.log | tail -20
fi

echo ""
echo "=== Test 3: Direct operations format test ==="
echo ""

# Test if the CLI can handle direct operations format
cat > test_operations.sh << 'EOF'
#!/bin/bash

# Simulate API response with operations
response='{
  "response": "I will create a test file for you.",
  "operations": [
    {
      "type": "file",
      "operation": "write", 
      "path": "direct_test.txt",
      "content": "This file was created from direct operations format"
    },
    {
      "type": "command",
      "command": "echo Operations test successful"
    }
  ]
}'

# This would be the response from the API
echo "$response"
EOF

chmod +x test_operations.sh

echo ""
echo "=== Summary ==="
echo "Test directory contents:"
ls -la
echo ""
echo "Check logs for detailed output"

cd ..
echo ""
echo "Test complete. Results in: $TEST_DIR/"