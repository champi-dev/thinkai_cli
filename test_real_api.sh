#!/bin/bash

echo "=== Testing with Real ThinkAI API ==="
echo ""

# First, let's test if the API is reachable
echo "1. Testing API connectivity..."
if curl -s -I "https://thinkai.lat" | grep -q "200\|301\|302"; then
    echo "✅ API is reachable"
else
    echo "❌ API not reachable"
fi

echo ""
echo "2. Testing API chat endpoint directly..."
# Test the API endpoint directly
response=$(curl -s -X POST "https://thinkai.lat/api/chat" \
    -H "Content-Type: application/json" \
    -d '{
        "message": "Create a hello world JavaScript file",
        "conversation_id": "test_conv_123",
        "context": []
    }')

echo "API Response:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

echo ""
echo "3. Testing with the CLI in interactive mode..."
# Create a test input
echo "create a hello world javascript file that prints Hello from ThinkAI" > test_prompt.txt

# Run the CLI with the test input
export CLIII_AGENTIC_MODE=true
export DEBUG_MODE=true
timeout 30 ./int.sh < test_prompt.txt

echo ""
echo "Test complete!"