#!/bin/bash

#
# Copyright 2025 Robert Lindley
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -euo pipefail # Exit on error, treat unset variables as errors, propagate errors in pipelines

# Constants
readonly API_URL="https://api.github.com/rate_limit"
readonly WARNING_THRESHOLD="${WARNING_THRESHOLD:-100}" # Default to 100, configurable via env var

# Input validation
if [[ $# -ne 1 ]]; then
  echo "::error::Usage: $0 <github-token>"
  exit 1
fi

readonly GITHUB_TOKEN="$1"

# Check for required tools
if ! command -v curl >/dev/null 2>&1; then
  echo "::error::curl is required but not installed."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "::error::jq is required but not installed."
  exit 1
fi

echo "Calling GitHub Rate Limit API..."
if ! RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$API_URL"); then
  echo "::error::Failed to call GitHub API."
  exit 1
fi

if [[ -z "$RESPONSE" ]]; then
  echo "::error::Failed to retrieve rate limit data from GitHub API."
  exit 1
fi

echo "$RESPONSE" >rate_limit.json

# Function to safely parse JSON values
parse_safe() {
  local query="$1"
  local value
  value=$(jq -r "$query // empty" rate_limit.json 2>/dev/null) || {
    echo "::warning::Failed to parse JSON with query: $query"
    echo "0"
    return
  }
  echo "${value:-0}"
}

# Extract rate limit data
readonly RATE_LIMIT=$(parse_safe '.rate.limit')
readonly RATE_REMAINING=$(parse_safe '.rate.remaining')
readonly RATE_RESET=$(parse_safe '.rate.reset')

readonly GRAPHQL_LIMIT=$(parse_safe '.graphql.limit')
readonly GRAPHQL_REMAINING=$(parse_safe '.graphql.remaining')
readonly GRAPHQL_RESET=$(parse_safe '.graphql.reset')

readonly SEARCH_LIMIT=$(parse_safe '.search.limit')
readonly SEARCH_REMAINING=$(parse_safe '.search.remaining')
readonly SEARCH_RESET=$(parse_safe '.search.reset')

# Function to format timestamp
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

readonly RESET_TIME=$(format_time "$RATE_RESET")
readonly GRAPHQL_RESET_TIME=$(format_time "$GRAPHQL_RESET")
readonly SEARCH_RESET_TIME=$(format_time "$SEARCH_RESET")

echo "GitHub API Rate Limit Status:"
echo "--------------------------------------------"
echo " Core API:  $RATE_REMAINING / $RATE_LIMIT  (Resets at $RESET_TIME)"
echo " GraphQL:   $GRAPHQL_REMAINING / $GRAPHQL_LIMIT  (Resets at $GRAPHQL_RESET_TIME)"
echo " Search:    $SEARCH_REMAINING / $SEARCH_LIMIT  (Resets at $SEARCH_RESET_TIME)"
echo "--------------------------------------------"

# Function to check limits
check_limits() {
  local api_name="$1"
  local remaining="$2"
  local limit="$3"
  local reset_time="$4"

  if [[ "$limit" -gt 0 ]] && [[ "$remaining" -le 0 ]]; then
    echo "::error::❌ $api_name API Rate Limit has been fully exhausted!"
    return 1
  elif [[ "$limit" -gt 0 ]] && [[ "$remaining" -lt "$WARNING_THRESHOLD" ]]; then
    echo "::warning::⚠️ $api_name API Rate Limit is low ($remaining remaining)!"
  fi
  return 0
}

# Check limits and accumulate exit status
exit_status=0
check_limits "GitHub Core" "$RATE_REMAINING" "$RATE_LIMIT" "$RESET_TIME" || exit_status=1
check_limits "GitHub GraphQL" "$GRAPHQL_REMAINING" "$GRAPHQL_LIMIT" "$GRAPHQL_RESET_TIME" || exit_status=1
check_limits "GitHub Search" "$SEARCH_REMAINING" "$SEARCH_LIMIT" "$SEARCH_RESET_TIME" || exit_status=1

# GitHub Step Summary
{
  echo "# :bar_chart: GitHub API Rate Limit Summary"
  echo ""
  echo "| API Type  | Remaining | Limit | Reset Time (UTC) |"
  echo "|-----------|----------|-------|------------------|"
  echo "| Core API  | $RATE_REMAINING | $RATE_LIMIT | $RESET_TIME |"
  echo "| GraphQL   | $GRAPHQL_REMAINING | $GRAPHQL_LIMIT | $GRAPHQL_RESET_TIME |"
  echo "| Search    | $SEARCH_REMAINING | $SEARCH_LIMIT | $SEARCH_RESET_TIME |"
  echo ""
} >>"$GITHUB_STEP_SUMMARY"

# Add warnings to summary
if [[ "$RATE_LIMIT" -gt 0 ]] && [[ "$RATE_REMAINING" -lt "$WARNING_THRESHOLD" ]]; then
  echo "⚠️ **Warning:** GitHub API rate limit is low ($RATE_REMAINING remaining)." >>"$GITHUB_STEP_SUMMARY"
fi
if [[ "$GRAPHQL_LIMIT" -gt 0 ]] && [[ "$GRAPHQL_REMAINING" -lt "$WARNING_THRESHOLD" ]]; then
  echo "⚠️ **Warning:** GitHub GraphQL API rate limit is low ($GRAPHQL_REMAINING remaining)." >>"$GITHUB_STEP_SUMMARY"
fi
if [[ "$SEARCH_LIMIT" -gt 0 ]] && [[ "$SEARCH_REMAINING" -lt "$WARNING_THRESHOLD" ]]; then
  echo "⚠️ **Warning:** GitHub Search API rate limit is low ($SEARCH_REMAINING remaining)." >>"$GITHUB_STEP_SUMMARY"
fi

echo "⏳ API limits reset hourly. Plan requests accordingly." >>"$GITHUB_STEP_SUMMARY"

exit "$exit_status"
