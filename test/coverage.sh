#!/bin/bash

# Coverage script for bash using kcov
# This script analyzes test coverage for the int.sh script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if kcov is installed
if ! command -v kcov &> /dev/null; then
    echo "kcov is not installed. Installing instructions:"
    echo "  Ubuntu/Debian: sudo apt-get install kcov"
    echo "  MacOS: brew install kcov"
    echo "  Or build from source: https://github.com/SimonKagstrom/kcov"
    echo ""
    echo "Alternatively, using bashcov (Ruby gem):"
    echo "  gem install bashcov"
    echo "  bashcov ./bats-core/bin/bats test/*.bats"
    exit 1
fi

# Create coverage directory
COVERAGE_DIR="$PROJECT_ROOT/coverage"
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# Run tests with coverage
echo "Running tests with coverage analysis..."

# For each test file, run with kcov
for test_file in "$PROJECT_ROOT/test"/*.bats; do
    test_name=$(basename "$test_file" .bats)
    echo "Running coverage for $test_name..."
    
    kcov --exclude-pattern=/usr,/tmp "$COVERAGE_DIR/$test_name" \
        "$PROJECT_ROOT/bats-core/bin/bats" "$test_file" || true
done

# Merge coverage results
echo "Merging coverage results..."
kcov --merge "$COVERAGE_DIR/merged" "$COVERAGE_DIR"/*/ || true

# Display coverage summary
echo ""
echo "Coverage Report:"
echo "================"

# Extract coverage percentage for int.sh
if [ -f "$COVERAGE_DIR/merged/index.html" ]; then
    # Try to extract coverage from HTML report
    coverage=$(grep -A5 "int.sh" "$COVERAGE_DIR/merged/index.html" | grep -oP '\d+\.\d+%' | head -1 || echo "N/A")
    echo "Coverage for int.sh: $coverage"
    echo ""
    echo "Detailed report available at: file://$COVERAGE_DIR/merged/index.html"
else
    echo "Coverage report not generated. Check kcov output above."
fi

# Alternative: Simple line coverage analysis
echo ""
echo "Simple Line Coverage Analysis:"
echo "=============================="

# Count total lines (excluding empty lines and comments)
total_lines=$(grep -v '^\s*#' "$PROJECT_ROOT/int.sh" | grep -v '^\s*$' | wc -l)
echo "Total executable lines: $total_lines"

# This is a simplified check - for accurate coverage, use kcov or bashcov
echo ""
echo "To ensure 100% coverage:"
echo "1. All functions must be called at least once"
echo "2. All conditional branches must be tested"
echo "3. All error paths must be covered"
echo "4. The main loop must be tested with various inputs"
echo ""
echo "Run all tests: ./bats-core/bin/bats test/*.bats"