#!/bin/bash

echo "=== ThinkAI CLI Fixed Demo ==="
echo ""
echo "This demo shows the key fixes:"
echo "1. Proper text streaming (character by character)"
echo "2. Correct file content extraction from code blocks"
echo "3. Proper command execution"
echo ""

# Source the functions
source ./int.sh

echo "--- Demo 1: Text Streaming ---"
stream_colored_text "This text appears character by character, creating a smooth streaming effect!" "\033[1;32m"
echo ""
sleep 1

echo -e "\n--- Demo 2: File Operations ---"
test_response='Here is your todo app in `app.js`:

```javascript
new Vue({
    el: "#app",
    data: {
        items: [],
        newItem: ""
    },
    methods: {
        addItem() {
            if (this.newItem.trim()) {
                this.items.push(this.newItem);
                this.newItem = "";
                this.saveItems();
            }
        },
        removeItem(index) {
            this.items.splice(index, 1);
            this.saveItems();
        },
        saveItems() {
            localStorage.setItem("todoItems", JSON.stringify(this.items));
        },
        loadItems() {
            const saved = localStorage.getItem("todoItems");
            if (saved) {
                this.items = JSON.parse(saved);
            }
        }
    },
    mounted() {
        this.loadItems();
    }
});
```

Run it with: `node app.js`'

# Parse and show operations
operations=$(parse_ai_response_to_operations "$test_response")
echo "Parsed operations:"
echo "$operations" | jq '.'

echo -e "\n--- Demo 3: Command Execution ---"
echo "Executing: ls -la | head -5"
execute_command_safe "ls -la | head -5"

echo -e "\n=== Demo Complete ==="
echo "The CLI now properly:"
echo "✓ Streams text character by character"
echo "✓ Extracts code blocks and saves them to correct files"
echo "✓ Executes commands safely"
echo "✓ Handles file operations correctly"