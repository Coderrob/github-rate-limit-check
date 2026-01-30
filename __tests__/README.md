# Tests for GitHub Rate Limit Check Action

This directory contains unit tests for the `entrypoint.sh` script.

## Running Tests

To run the tests locally:

```bash
./__tests__/test_entrypoint.sh
```

## Test Coverage

The tests cover:

- `parse_safe` function: JSON parsing with valid and invalid queries
- `format_time` function: Timestamp formatting and edge cases
- `check_limits` function: Normal operation, warning threshold, and exhausted limits
- Main logic: Data extraction from mock JSON

## CI Integration

Tests are automatically run in the CI workflow on pushes and pull requests.

## Mock Data

Tests use static mock JSON data to avoid dependencies on live API calls and ensure consistent results.
