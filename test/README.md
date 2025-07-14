# Test Suite for CLIII

This directory contains comprehensive unit and end-to-end tests for the CLIII (ThinkAI CLI) application.

## Test Structure

```
test/
├── README.md           # This file
├── test_helper.bash    # Common test utilities and setup
├── unit_tests.bats     # Unit tests for individual functions
├── e2e_tests.bats      # End-to-end integration tests
├── edge_cases.bats     # Edge case and boundary tests
├── coverage.sh         # Coverage analysis script
└── mocks/
    └── curl            # Mock curl command for testing
```

## Running Tests

### Run all tests
```bash
./bats-core/bin/bats test/*.bats
```

### Run specific test files
```bash
# Unit tests only
./bats-core/bin/bats test/unit_tests.bats

# E2E tests only
./bats-core/bin/bats test/e2e_tests.bats

# Edge cases only
./bats-core/bin/bats test/edge_cases.bats
```

### Run tests with verbose output
```bash
./bats-core/bin/bats test/*.bats -v
```

## Test Coverage

The test suite aims for 100% code coverage of `int.sh`. Coverage includes:

### Unit Tests (`unit_tests.bats`)
- `send_to_thinkai()` - API communication with mocked curl
- `display_colored_text()` - Text formatting and ANSI color handling
- `display_animation()` - Loading animation functionality
- `handle_file_operations()` - File writing operations
- `execute_command()` - Command execution functionality

### E2E Tests (`e2e_tests.bats`)
- Full interactive loop testing
- Exit command handling
- Normal chat interactions
- Command execution from responses
- File operations from responses
- Multiple interaction sessions
- Error handling and recovery
- Special character handling

### Edge Cases (`edge_cases.bats`)
- Malformed JSON responses
- Missing response fields
- Very long inputs/outputs
- Special characters in all contexts
- File paths with spaces
- Command failures
- Concurrent operations
- Animation interruption

## Test Helpers

The `test_helper.bash` file provides:
- Mock setup and teardown
- Function extraction without main loop execution
- ANSI color stripping utilities
- File assertion helpers
- Temporary directory management

## Mocking

The test suite uses a mock `curl` command to simulate API responses without making real network calls. The mock supports:
- Custom response content via `MOCK_CURL_OUTPUT`
- Failure simulation via `MOCK_CURL_EXIT_CODE`
- Multiple response sequences for complex tests

## Coverage Analysis

To generate a coverage report:

```bash
./test/coverage.sh
```

This requires `kcov` to be installed:
- Ubuntu/Debian: `sudo apt-get install kcov`
- MacOS: `brew install kcov`

## Continuous Integration

Tests run automatically on:
- Push to main/develop branches
- Pull requests to main
- Multiple OS environments (Ubuntu, macOS)

See `.github/workflows/test.yml` for CI configuration.

## Writing New Tests

When adding new functionality:

1. Add unit tests for new functions in `unit_tests.bats`
2. Add integration tests in `e2e_tests.bats` if the feature affects user interaction
3. Add edge cases in `edge_cases.bats` for boundary conditions
4. Ensure tests are independent and can run in any order
5. Use descriptive test names that explain what is being tested

Example test structure:
```bash
@test "function_name handles specific scenario" {
    # Setup
    extract_functions
    export MOCK_CURL_OUTPUT='{"response": "test"}'
    
    # Execute
    run function_name "argument"
    
    # Assert
    assert_success
    assert_output --partial "expected output"
}
```