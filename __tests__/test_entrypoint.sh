#!/bin/bash

# Test script for entrypoint.sh
# This script tests the functions and logic of entrypoint.sh with mock data

set -euo pipefail

# Source the functions from entrypoint.sh
# We need to define the functions here or source them carefully

# Mock data
MOCK_JSON='{
  "rate": {
    "limit": 5000,
    "remaining": 4990,
    "reset": 1738128000
  },
  "graphql": {
    "limit": 5000,
    "remaining": 4990,
    "reset": 1738128000
  },
  "search": {
    "limit": 30,
    "remaining": 25,
    "reset": 1738128000
  }
}'

# Create mock rate_limit.json
echo "$MOCK_JSON" > rate_limit.json

# Define functions from entrypoint.sh (copied for testing)
parse_safe() {
  local query="$1"
  local value
  value=$(jq -r "$query // empty" rate_limit.json 2>/dev/null) || {
    echo "0"
    return
  }
  echo "${value:-0}"
}

format_time() {
  local timestamp="$1"
  if [[ "$timestamp" -gt 0 ]]; then
    if command -v gdate >/dev/null 2>&1; then
      gdate -u -d "@$timestamp" "+%Y-%m-%d %H:%M:%S UTC"
    elif date -u -d "@$timestamp" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null; then
      date -u -d "@$timestamp" "+%Y-%m-%d %H:%M:%S UTC"
    else
      echo "N/A (date command unsupported)"
    fi
  else
    echo "N/A"
  fi
}

check_limits() {
  local api_name="$1"
  local remaining="$2"
  local limit="$3"
  local reset_time="$4"
  local threshold="$5"

  if [[ "$limit" -gt 0 ]] && [[ "$remaining" -le 0 ]]; then
    echo "::error::❌ $api_name API Rate Limit has been fully exhausted!"
    return 1
  elif [[ "$limit" -gt 0 ]] && [[ "$remaining" -lt "$threshold" ]]; then
    echo "::warning::⚠️ $api_name API Rate Limit is low ($remaining remaining)!"
  fi
  return 0
}

# Test parse_safe
echo "Testing parse_safe function..."
RATE_LIMIT=$(parse_safe '.rate.limit')
if [[ "$RATE_LIMIT" != "5000" ]]; then
  echo "ERROR: Expected 5000, got $RATE_LIMIT"
  exit 1
fi

RATE_REMAINING=$(parse_safe '.rate.remaining')
if [[ "$RATE_REMAINING" != "4990" ]]; then
  echo "ERROR: Expected 4990, got $RATE_REMAINING"
  exit 1
fi

# Test invalid query
INVALID=$(parse_safe '.invalid.path')
if [[ "$INVALID" != "0" ]]; then
  echo "ERROR: Expected 0 for invalid path, got $INVALID"
  exit 1
fi

echo "✅ parse_safe tests passed"

# Test format_time
echo "Testing format_time function..."
RESET_TIME=$(format_time "1738128000")
if [[ "$RESET_TIME" == "N/A" ]]; then
  echo "ERROR: format_time failed to format timestamp"
  exit 1
fi

NA_TIME=$(format_time "0")
if [[ "$NA_TIME" != "N/A" ]]; then
  echo "ERROR: Expected N/A for 0 timestamp, got $NA_TIME"
  exit 1
fi

echo "✅ format_time tests passed"

# Test check_limits
echo "Testing check_limits function..."

# Test normal case (no warning)
OUTPUT=$(check_limits "Test API" "200" "5000" "reset_time" "100")
if [[ -n "$OUTPUT" ]]; then
  echo "ERROR: Expected no output for normal case, got: $OUTPUT"
  exit 1
fi

# Test warning case
OUTPUT=$(check_limits "Test API" "50" "5000" "reset_time" "100")
EXPECTED="::warning::⚠️ Test API API Rate Limit is low (50 remaining)!"
if [[ "$OUTPUT" != "$EXPECTED" ]]; then
  echo "ERROR: Expected '$EXPECTED', got: '$OUTPUT'"
  exit 1
fi

# Test exhausted case
OUTPUT=$(check_limits "Test API" "0" "5000" "reset_time" "100" 2>&1 || true)
EXPECTED="::error::❌ Test API API Rate Limit has been fully exhausted!"
if [[ "$OUTPUT" != "$EXPECTED" ]]; then
  echo "ERROR: Expected '$EXPECTED', got: '$OUTPUT'"
  exit 1
fi

echo "✅ check_limits tests passed"

# Test main logic simulation
echo "Testing main logic simulation..."

# Extract data
readonly TEST_RATE_LIMIT=$(parse_safe '.rate.limit')
readonly TEST_RATE_REMAINING=$(parse_safe '.rate.remaining')
readonly TEST_RATE_RESET=$(parse_safe '.rate.reset')

readonly TEST_GRAPHQL_LIMIT=$(parse_safe '.graphql.limit')
readonly TEST_GRAPHQL_REMAINING=$(parse_safe '.graphql.remaining')
readonly TEST_GRAPHQL_RESET=$(parse_safe '.graphql.reset')

readonly TEST_SEARCH_LIMIT=$(parse_safe '.search.limit')
readonly TEST_SEARCH_REMAINING=$(parse_safe '.search.remaining')
readonly TEST_SEARCH_RESET=$(parse_safe '.search.reset')

# Check that values are correct
if [[ "$TEST_RATE_LIMIT" != "5000" ]] || [[ "$TEST_RATE_REMAINING" != "4990" ]]; then
  echo "ERROR: Rate limit extraction failed"
  exit 1
fi

if [[ "$TEST_GRAPHQL_LIMIT" != "5000" ]] || [[ "$TEST_GRAPHQL_REMAINING" != "4990" ]]; then
  echo "ERROR: GraphQL limit extraction failed"
  exit 1
fi

if [[ "$TEST_SEARCH_LIMIT" != "30" ]] || [[ "$TEST_SEARCH_REMAINING" != "25" ]]; then
  echo "ERROR: Search limit extraction failed"
  exit 1
fi

echo "✅ Main logic tests passed"

# Clean up
rm -f rate_limit.json

echo "🎉 All tests passed!"