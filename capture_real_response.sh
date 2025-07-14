#!/bin/bash

# Capture the real API response to see the exact format

echo "=== Capturing Real API Response ==="

# Make a direct API call and save raw response
raw_response=$(curl -s -X POST "https://thinkai.lat/api/chat" \
    -H "Content-Type: application/json" \
    -d '{
        "message": "create a simple hello.js file that prints hello world",
        "conversation_id": "test_debug_123",
        "context": []
    }')

# Save raw response
echo "$raw_response" > raw_response.json

# Extract just the response text
response_text=$(echo "$raw_response" | jq -r '.response')

# Save the extracted text
echo "$response_text" > response_text.txt

echo "Raw response saved to: raw_response.json"
echo "Response text saved to: response_text.txt"
echo ""
echo "First 500 chars of response text:"
echo "$response_text" | head -c 500
echo ""
echo ""
echo "Checking for code blocks in response text:"
echo "$response_text" | grep -n '```' || echo "No code blocks found with grep"
echo ""
echo "Hex dump around potential code block:"
echo "$response_text" | od -c | grep -A2 -B2 '`' | head -20