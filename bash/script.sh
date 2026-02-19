#!/bin/bash

# ============================================================
# Script: read_properties.sh
# Description: Detects which .properties file was changed
#              by the triggering commit and extracts values
# ============================================================

set -euo pipefail

echo "🔍 Triggered by commit: ${GITHUB_SHA}"

# ----------------------------
# Detect which .properties file was changed in the triggering commit
# ----------------------------
echo "🔎 Detecting changed .properties file in commit ${GITHUB_SHA}..."

CHANGED_PROPERTIES_FILE=$(git diff-tree --no-commit-id -r --name-only "$GITHUB_SHA" | grep -E '\.properties$')

# ----------------------------
# Validate only one .properties file was changed
# ----------------------------
FILE_COUNT=$(echo "$CHANGED_PROPERTIES_FILE" | grep -c '\.properties' || true)

if [[ -z "$CHANGED_PROPERTIES_FILE" ]]; then
  echo "❌ ERROR: No .properties file found in commit ${GITHUB_SHA}."
  exit 1
fi

if [[ "$FILE_COUNT" -gt 1 ]]; then
  echo "⚠️  WARNING: Multiple .properties files changed in this commit:"
  echo "$CHANGED_PROPERTIES_FILE"
  echo ""
  echo "Processing all detected files..."
fi

# ----------------------------
# Loop through each changed .properties file
# (Handles single or multiple changed files)
# ----------------------------
while IFS= read -r PROPERTIES_FILE; do

  echo ""
  echo "=========================================="
  echo "📄 Processing: ${PROPERTIES_FILE}"
  echo "=========================================="

  # Validate file exists in workspace
  if [[ ! -f "$PROPERTIES_FILE" ]]; then
    echo "❌ ERROR: '${PROPERTIES_FILE}' not found in workspace."
    exit 1
  fi

  echo "---------- File Content ----------"
  cat "$PROPERTIES_FILE"
  echo "----------------------------------"

  # ----------------------------
  # Parse values from the file
  # ----------------------------
  ARTIFACT_ID=$(grep -E '^artifactID=' "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
  VERSION=$(grep -E '^version='        "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
  GROUP_ID=$(grep -E '^groupID='       "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '[:space:]')

  # ----------------------------
  # Validate extracted values
  # ----------------------------
  if [[ -z "$ARTIFACT_ID" || -z "$VERSION" || -z "$GROUP_ID" ]]; then
    echo "❌ ERROR: One or more values could not be extracted from '${PROPERTIES_FILE}'."
    echo "    artifactID : '${ARTIFACT_ID:-NOT FOUND}'"
    echo "    version    : '${VERSION:-NOT FOUND}'"
    echo "    groupID    : '${GROUP_ID:-NOT FOUND}'"
    exit 1
  fi

  # ----------------------------
  # Print extracted values
  # ----------------------------
  echo ""
  echo "✅ Extracted Values from ${PROPERTIES_FILE}:"
  echo "    artifactID : ${ARTIFACT_ID}"
  echo "    version    : ${VERSION}"
  echo "    groupID    : ${GROUP_ID}"

  # ----------------------------
  # Export to GitHub Actions environment
  # Prefix var names with sanitized filename to avoid collisions
  # e.g. API1_ARTIFACT_ID, API2_ARTIFACT_ID etc.
  # ----------------------------
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    # Extract base filename without extension for prefix e.g. API1, API2
    FILE_PREFIX=$(basename "$PROPERTIES_FILE" .properties | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    echo "${FILE_PREFIX}_ARTIFACT_ID=${ARTIFACT_ID}" >> "$GITHUB_ENV"
    echo "${FILE_PREFIX}_VERSION=${VERSION}"          >> "$GITHUB_ENV"
    echo "${FILE_PREFIX}_GROUP_ID=${GROUP_ID}"        >> "$GITHUB_ENV"

    # Also export generic vars (will hold the last processed file's values
    # if multiple files changed - useful when only one file changes at a time)
    echo "ARTIFACT_ID=${ARTIFACT_ID}" >> "$GITHUB_ENV"
    echo "VERSION=${VERSION}"         >> "$GITHUB_ENV"
    echo "GROUP_ID=${GROUP_ID}"       >> "$GITHUB_ENV"
    echo "CHANGED_PROPERTIES_FILE=${PROPERTIES_FILE}" >> "$GITHUB_ENV"

    echo "📤 Exported: ${FILE_PREFIX}_ARTIFACT_ID, ${FILE_PREFIX}_VERSION, ${FILE_PREFIX}_GROUP_ID"
  fi

done <<< "$CHANGED_PROPERTIES_FILE"

echo ""
echo "✅ Done processing all changed .properties files."