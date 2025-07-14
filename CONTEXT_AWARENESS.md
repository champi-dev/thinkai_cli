# ThinkAI CLI - Context Awareness & Continuity

## Overview

The enhanced ThinkAI CLI now features comprehensive context awareness that:
- **Analyzes your entire codebase** automatically
- **Maintains conversation context** across sessions
- **Intelligently retrieves relevant files** based on your queries
- **Provides the AI with deep understanding** of your project

## Key Features

### 1. Automatic Codebase Analysis

When you start the CLI in a project directory (detected by .git, package.json, etc.), it automatically:
- Scans all code files
- Extracts imports, functions, and classes
- Creates a searchable index
- Updates every 24 hours

```bash
# Manual analysis
> /analyze

# View current context
> /context
```

### 2. Intelligent Context Retrieval

When you ask about code, the CLI:
- Extracts keywords from your query
- Searches the codebase index
- Includes relevant file contents in the AI context
- Prioritizes files based on relevance

### 3. Conversation Continuity

Every conversation is preserved with:
- Full message history
- Timestamps for each interaction
- Context from previous messages
- Codebase awareness maintained across sessions

## How It Works

### Codebase Indexing

The CLI creates an index at `~/.cliii/context/codebase_index.json` containing:

```json
{
  "project_root": "/path/to/project",
  "files": [
    {
      "path": "src/server.js",
      "extension": "js",
      "lines": 150,
      "imports": "express, jwt, bcrypt",
      "functions": "authenticate, createUser, login",
      "classes": ""
    }
  ],
  "summary": {
    "total_files": 42,
    "total_lines": 3500,
    "languages": {
      "js": 25,
      "py": 10,
      "json": 7
    }
  }
}
```

### Context Enhancement

When you send a message, the CLI:

1. **Retrieves conversation history** (last 10 messages)
2. **Searches for relevant files** based on your query
3. **Combines both contexts** into an enhanced payload
4. **Sends to AI** with full project awareness

### Example Workflow

```bash
> I need to optimize the fibonacci function

# CLI automatically:
# 1. Finds files containing "fibonacci"
# 2. Reads their content
# 3. Includes in AI context
# 4. AI responds with awareness of your actual code

> Can you add memoization to it?

# AI knows exactly which function you're referring to
# and can provide specific, contextual improvements
```

## Configuration

### Environment Variables

```bash
# Disable automatic analysis
export CLIII_AUTO_ANALYZE=false

# Change analysis age threshold (hours)
export CLIII_ANALYZE_AGE=48
```

### Index Customization

The codebase analysis covers:
- **Languages**: JS, TS, Python, Java, C/C++, Go, Rust, Ruby, PHP, Swift, Kotlin, Scala, Bash
- **Config Files**: package.json, requirements.txt, pom.xml, build.gradle, Cargo.toml, etc.
- **Excludes**: node_modules, .git, dist, build directories

## Advanced Usage

### Multi-Project Support

The CLI maintains separate indices per project:
```bash
cd project1 && ./int.sh  # Analyzes project1
cd project2 && ./int.sh  # Analyzes project2
```

### Context Limits

- **Max files per query**: 5 (configurable)
- **Lines per file**: First 50 lines
- **Conversation history**: Last 10 messages

### Performance

- Initial analysis: ~1-5 seconds for medium projects
- Query enhancement: <100ms
- No impact on response time

## Benefits

1. **Accurate Responses**: AI understands your actual code structure
2. **Contextual Suggestions**: Recommendations fit your project patterns
3. **Reduced Explanations**: No need to describe your codebase
4. **Seamless Workflow**: Works automatically in the background

## Troubleshooting

### Index Not Created
- Check if you're in a project directory
- Run `/analyze` manually
- Ensure jq is installed

### Context Not Working
- Verify index exists: `ls ~/.cliii/context/`
- Check file permissions
- Review index content: `jq . ~/.cliii/context/codebase_index.json`

### Performance Issues
- Exclude large directories in analysis
- Reduce max files per query
- Clear old indices periodically