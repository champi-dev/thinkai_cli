#!/bin/bash

# Test backtick detection

test_string='```javascript
console.log("hello");
```'

echo "Test string:"
echo "$test_string"
echo ""

echo "Line-by-line processing:"
line_num=0
while IFS= read -r line; do
    ((line_num++))
    echo "Line $line_num: '$line'"
    
    if [[ "$line" =~ ^\`\`\`([a-zA-Z0-9]*) ]]; then
        echo "  -> Matches code block START with language: '${BASH_REMATCH[1]}'"
    elif [[ "$line" =~ ^\`\`\`$ ]]; then
        echo "  -> Matches code block END"
    else
        echo "  -> Regular line"
    fi
done <<< "$test_string"