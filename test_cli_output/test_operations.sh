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
