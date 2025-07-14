# ThinkAI CLI Enhanced Features

This document describes the automatic error recovery, self-healing capabilities, and local execution features added to ThinkAI CLI.

## New Features

### 1. Automatic Error Recovery
- **Exponential Backoff**: API calls automatically retry up to 5 times with increasing delays
- **Network Detection**: Checks connectivity before API calls and waits for network recovery
- **Response Validation**: Automatically validates and attempts to fix malformed API responses

### 2. Self-Healing Capabilities
- **JSON Repair**: Automatically fixes corrupted conversation files
- **Backup System**: Creates backups before modifying important files
- **Operation Journaling**: Tracks operations for crash recovery
- **State Restoration**: Recovers from interrupted operations on restart

### 3. Enhanced Local Execution
- **Dangerous Command Detection**: Warns before executing potentially harmful commands
- **Dry-Run Mode**: Preview operations without executing them
- **Auto-Fix Mode**: Automatically resolves common errors (missing dependencies, etc.)
- **Execution Verification**: Shows verification steps after each operation

### 4. Safety Features
- **File Backups**: Automatic backups before file modifications
- **Operation Preview**: See what will happen before it happens
- **Rollback Support**: Restore from backups if something goes wrong
- **Comprehensive Logging**: All errors logged to `~/.cliii/errors.log`

## How to Use

### Quick Start
```bash
# Apply enhancements to existing installation
chmod +x enhance_cli.sh
./enhance_cli.sh

# Run enhanced CLI
./int.sh
```

### Environment Variables
```bash
# Enable/disable auto-fix mode (default: true)
export CLIII_AUTO_FIX=true

# Enable dry-run mode to preview operations (default: false)
export CLIII_DRY_RUN=true

# Show verification steps after operations (default: true)
export CLIII_SHOW_VERIFY=true

# Skip dangerous command confirmation (default: false)
export CLIII_FORCE=true
```

## Verification Guide

### 1. Test Automatic Error Recovery
```bash
# Simulate network failure
sudo iptables -A OUTPUT -d api.thinkai.net -j DROP
./int.sh
# Type a message - watch it retry with backoff
sudo iptables -D OUTPUT -d api.thinkai.net -j DROP
```

### 2. Test JSON Self-Healing
```bash
# Corrupt a conversation file
echo '{"invalid": json,}' > ~/.cliii/conversations/test.json
./int.sh
# Switch to test conversation - watch it auto-repair
/switch test
```

### 3. Test Dry-Run Mode
```bash
export CLIII_DRY_RUN=true
./int.sh
# Ask it to create files or run commands
# Verify nothing actually executes
export CLIII_DRY_RUN=false
```

### 4. Test Auto-Fix Features
```bash
# Test npm auto-initialization
cd /tmp/test_project
./int.sh
# Ask: "run npm install express"
# Watch it auto-create package.json first
```

### 5. Test Backup System
```bash
# Create a file
echo "original content" > test.txt
./int.sh
# Ask: "modify test.txt to say 'new content'"
# Check backup was created
ls ~/.cliii/backups/
```

### 6. Run Comprehensive Tests
```bash
chmod +x test_enhanced_features.sh
./test_enhanced_features.sh
```

## Verification Commands

After any operation, you can verify locally:

### File Operations
```bash
# List files in current directory
ls -la

# Check file content
cat filename.txt

# Check file was created with correct permissions
stat filename.txt

# See all recent file changes
find . -type f -mmin -5
```

### Command Execution
```bash
# Check last command exit status
echo $?

# View command output history
history | tail -20

# Check if process is running
ps aux | grep process_name

# Monitor system resources
htop
```

### Error Checking
```bash
# View error log
cat ~/.cliii/errors.log

# Check conversation files
ls ~/.cliii/conversations/

# Verify backups
ls -la ~/.cliii/backups/

# Check journal entries
cat ~/.cliii/journal/operations_$(date +%Y%m%d).json | jq .
```

## Troubleshooting

### If API calls keep failing:
1. Check network: `ping api.thinkai.net`
2. View errors: `tail -f ~/.cliii/errors.log`
3. Clear corrupted data: `rm -rf ~/.cliii/conversations/*.json`
4. Restart with fresh state: `rm -rf ~/.cliii && ./int.sh`

### If files get corrupted:
1. Restore from backup: `cp ~/.cliii/backups/file.backup ~/.cliii/file`
2. Let self-heal fix it: Just run the command again
3. Check JSON validity: `jq . ~/.cliii/conversations/current.json`

### If commands fail:
1. Enable verbose mode: `export CLIII_VERBOSE=true`
2. Use dry-run first: `export CLIII_DRY_RUN=true`
3. Check permissions: `ls -la`
4. Review command history: `cat ~/.cliii/journal/operations_*.json`

## Performance Impact

The enhanced features add minimal overhead:
- API calls: ~100ms for retry logic
- File operations: ~10ms for backup creation
- JSON validation: ~5ms per file
- Network checks: ~50ms per check

## Security Considerations

1. **Dangerous Commands**: Always prompts before `rm -rf`, `dd`, `mkfs`, etc.
2. **Backups**: Keeps last 5 versions of each file
3. **Logging**: Sensitive data is not logged
4. **Network**: Only connects to api.thinkai.net
5. **Permissions**: Respects user file permissions

## Contributing

To add new auto-fix rules:
1. Edit `enhanced_functions.sh`
2. Add pattern to `execute_command_safe` function
3. Test with `test_enhanced_features.sh`
4. Submit PR with test case