#!/bin/bash

# Run Tests Script
# This script runs all tests for the GitHub Rate Limit Check action

set -euo pipefail

echo "🧪 Running tests for GitHub Rate Limit Check..."

# Check if we're in the correct directory
if [[ ! -f "action.yml" ]]; then
  echo "::error::Must be run from the repository root"
  exit 1
fi

# Check for required tools
if ! command -v jq >/dev/null 2>&1; then
  echo "::error::jq is required but not installed"
  exit 1
fi

# Run unit tests
echo "📋 Running unit tests..."
if [[ -f "__tests__/test_entrypoint.sh" ]]; then
  bash "__tests__/test_entrypoint.sh"
else
  echo "::error::Unit tests not found at __tests__/test_entrypoint.sh"
  exit 1
fi

# Run shellcheck on scripts
echo "🔍 Running ShellCheck..."
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck scripts/*.sh; then
    echo "✅ ShellCheck passed"
  else
    echo "::warning::ShellCheck found issues (warnings only)"
  fi
else
  echo "::warning::ShellCheck not available, skipping linting"
fi

# Validate action.yml syntax (basic check)
echo "📄 Validating action.yml..."
if [[ -f "action.yml" ]]; then
  if command -v yamllint >/dev/null 2>&1; then
    yamllint action.yml || echo "::warning::YAML linting failed"
  else
    echo "::warning::yamllint not available, skipping YAML validation"
  fi
  echo "✅ Action validation completed"
else
  echo "::error::action.yml not found"
  exit 1
fi

echo "🎉 All tests completed successfully!"