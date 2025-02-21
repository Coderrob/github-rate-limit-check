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

set -e # Exit on error

GITHUB_TOKEN=$1
API_URL="https://api.github.com/rate_limit"

echo "Calling GitHub Rate Limit API..."
RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" $API_URL)

if [ -z "$RESPONSE" ]; then
  echo "::error::Failed to retrieve rate limit data from GitHub API."
  exit 1
fi

echo "$RESPONSE" >rate_limit.json

parse_safe() {
  local value=$(jq -r "$1 // empty" rate_limit.json)
  echo "${value:-0}" # Default to 0 if empty/null
}

RATE_LIMIT=$(parse_safe '.rate.limit')
RATE_REMAINING=$(parse_safe '.rate.remaining')
RATE_RESET=$(parse_safe '.rate.reset')

GRAPHQL_LIMIT=$(parse_safe '.graphql.limit')
GRAPHQL_REMAINING=$(parse_safe '.graphql.remaining')
GRAPHQL_RESET=$(parse_safe '.graphql.reset')

SEARCH_LIMIT=$(parse_safe '.search.limit')
SEARCH_REMAINING=$(parse_safe '.search.remaining')
SEARCH_RESET=$(parse_safe '.search.reset')

format_time() {
  if [ "$1" -gt 0 ]; then
    date -u -d "@$1" "+%Y-%m-%d %H:%M:%S UTC"
  else
    echo "N/A"
  fi
}

RESET_TIME=$(format_time "$RATE_RESET")
GRAPHQL_RESET_TIME=$(format_time "$GRAPHQL_RESET")
SEARCH_RESET_TIME=$(format_time "$SEARCH_RESET")

echo "GitHub API Rate Limit Status:"
echo "--------------------------------------------"
echo " Core API:  $RATE_REMAINING / $RATE_LIMIT  (Resets at $RESET_TIME)"
echo " GraphQL:   $GRAPHQL_REMAINING / $GRAPHQL_LIMIT  (Resets at $GRAPHQL_RESET_TIME)"
echo " Search:    $SEARCH_REMAINING / $SEARCH_LIMIT  (Resets at $SEARCH_RESET_TIME)"
echo "--------------------------------------------"

# Core API Limits
if [ "$RATE_LIMIT" -gt 0 ] && [ "$RATE_REMAINING" -le 0 ]; then
  echo "::error::❌ GitHub API Rate Limit has been fully exhausted!"
  exit 1
elif [ "$RATE_LIMIT" -gt 0 ] && [ "$RATE_REMAINING" -lt 100 ]; then
  echo "::warning::⚠️ GitHub API Rate Limit is low ($RATE_REMAINING remaining)!"
fi

# GraphQL Limits
if [ "$GRAPHQL_LIMIT" -gt 0 ] && [ "$GRAPHQL_REMAINING" -le 0 ]; then
  echo "::error::❌ GitHub GraphQL API Rate Limit has been fully exhausted!"
  exit 1
elif [ "$GRAPHQL_LIMIT" -gt 0 ] && [ "$GRAPHQL_REMAINING" -lt 100 ]; then
  echo "::warning::⚠️ GitHub GraphQL API Rate Limit is low ($GRAPHQL_REMAINING remaining)!"
fi

# Search Limits
if [ "$SEARCH_LIMIT" -gt 0 ] && [ "$SEARCH_REMAINING" -le 0 ]; then
  echo "::error::❌ GitHub Search API Rate Limit has been fully exhausted!"
  exit 1
elif [ "$SEARCH_LIMIT" -gt 0 ] && [ "$SEARCH_REMAINING" -lt 100 ]; then
  echo "::warning::⚠️ GitHub Search API Rate Limit is low ($SEARCH_REMAINING remaining)!"
fi

# GitHub Step Summary
echo "# :bar_chart: GitHub API Rate Limit Summary" >>$GITHUB_STEP_SUMMARY
echo "" >>$GITHUB_STEP_SUMMARY
echo "| API Type  | Remaining | Limit | Reset Time (UTC) |" >>$GITHUB_STEP_SUMMARY
echo "|-----------|----------|-------|------------------|" >>$GITHUB_STEP_SUMMARY
echo "| Core API  | $RATE_REMAINING | $RATE_LIMIT | $RESET_TIME |" >>$GITHUB_STEP_SUMMARY
echo "| GraphQL   | $GRAPHQL_REMAINING | $GRAPHQL_LIMIT | $GRAPHQL_RESET_TIME |" >>$GITHUB_STEP_SUMMARY
echo "| Search    | $SEARCH_REMAINING | $SEARCH_LIMIT | $SEARCH_RESET_TIME |" >>$GITHUB_STEP_SUMMARY
echo "" >>$GITHUB_STEP_SUMMARY

if [ "$RATE_LIMIT" -gt 0 ] && [ "$RATE_REMAINING" -lt 100 ]; then
  echo "⚠️ **Warning:** GitHub API rate limit is low ($RATE_REMAINING remaining)." >>$GITHUB_STEP_SUMMARY
fi
if [ "$GRAPHQL_LIMIT" -gt 0 ] && [ "$GRAPHQL_REMAINING" -lt 100 ]; then
  echo "⚠️ **Warning:** GitHub GraphQL API rate limit is low ($GRAPHQL_REMAINING remaining)." >>$GITHUB_STEP_SUMMARY
fi
if [ "$SEARCH_LIMIT" -gt 0 ] && [ "$SEARCH_REMAINING" -lt 100 ]; then
  echo "⚠️ **Warning:** GitHub Search API rate limit is low ($SEARCH_REMAINING remaining)." >>$GITHUB_STEP_SUMMARY
fi

echo "⏳ API limits reset periodically. Plan requests accordingly." >>$GITHUB_STEP_SUMMARY
