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

PROPERTIES_FILE=$(git diff-tree --no-commit-id -r --name-only "$GITHUB_SHA" | grep -E '\.properties$')

# ----------------------------
# Validate a .properties file was changed
# ----------------------------
if [[ -z "$PROPERTIES_FILE" ]]; then
  echo "❌ ERROR: No .properties file found in commit ${GITHUB_SHA}."
  exit 1
fi

echo ""
echo "=========================================="
echo "📄 Changed File Detected: ${PROPERTIES_FILE}"
echo "=========================================="

# ----------------------------
# Validate file exists in workspace
# ----------------------------
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
TEST_ID=$(grep -E '^testID='        "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '[:space:]')

# ----------------------------
# Validate extracted values
# ----------------------------
if [[ -z "$ARTIFACT_ID" || -z "$VERSION" || -z "$GROUP_ID" ]]; then
  echo "❌ ERROR: One or more values could not be extracted from '${PROPERTIES_FILE}'."
  echo "    artifactID : '${ARTIFACT_ID:-NOT FOUND}'"
  echo "    version    : '${VERSION:-NOT FOUND}'"
  echo "    groupID    : '${GROUP_ID:-NOT FOUND}'"
  echo "    testID     : '${TEST_ID:-NOT FOUND}'"
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
echo "    testID     : ${TEST_ID}"

# ----------------------------
# Export to GitHub Actions environment
# ----------------------------
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ARTIFACT_ID=${ARTIFACT_ID}"                   >> "$GITHUB_ENV"
  echo "VERSION=${VERSION}"                           >> "$GITHUB_ENV"
  echo "GROUP_ID=${GROUP_ID}"                         >> "$GITHUB_ENV"
  echo "TEST_ID=${TEST_ID}"                         >> "$GITHUB_ENV"
  echo "CHANGED_PROPERTIES_FILE=${PROPERTIES_FILE}"   >> "$GITHUB_ENV"

  echo ""
  echo "📤 Exported to GitHub Actions environment:"
  echo "    CHANGED_PROPERTIES_FILE : ${PROPERTIES_FILE}"
  echo "    ARTIFACT_ID             : ${ARTIFACT_ID}"
  echo "    VERSION                 : ${VERSION}"
  echo "    GROUP_ID                : ${GROUP_ID}"
  echo "    TEST_ID                 : ${TEST_ID}"
fi

echo ""
echo "✅ Done."