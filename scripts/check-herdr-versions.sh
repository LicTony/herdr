#!/usr/bin/env bash
# check-herdr-versions.sh
# Usage: ./check-herdr-versions.sh [search-directory]
# Finds all herdr.sh files under <search-directory> and reports those
# whose version doesn't match the source-of-truth herdr.sh in this repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HERDR="${SCRIPT_DIR}/../herdr.sh"
SEARCH_DIR="${1:-/home/siranthony/MisProyectos}"

# ── Validation ────────────────────────────────────────────────────────────────

if [[ ! -d "$SEARCH_DIR" ]]; then
  echo "Error: '${SEARCH_DIR}' is not a directory." >&2
  exit 1
fi

if [[ ! -f "$SOURCE_HERDR" ]]; then
  echo "Error: source-of-truth not found at '${SOURCE_HERDR}'." >&2
  exit 1
fi

# ── Extract source version ────────────────────────────────────────────────────

SOURCE_VERSION=$(grep '^# Version:' "$SOURCE_HERDR" | awk '{print $3}')

if [[ -z "$SOURCE_VERSION" ]]; then
  echo "Error: could not extract version from '${SOURCE_HERDR}'." >&2
  exit 1
fi

echo "Source version : ${SOURCE_VERSION}"
echo "Searching in   : ${SEARCH_DIR}"
echo "───────────────────────────────────────────"

# ── Find and compare ──────────────────────────────────────────────────────────

mismatches=0

while IFS= read -r -d '' herdr_file; do
  # Skip the source itself
  if [[ "$(realpath "$herdr_file")" == "$(realpath "$SOURCE_HERDR")" ]]; then
    continue
  fi

  file_version=$(grep '^# Version:' "$herdr_file" | awk '{print $3}')

  if [[ -z "$file_version" ]]; then
    echo "  [NO VERSION]  ${herdr_file}"
    ((mismatches++))
  elif [[ "$file_version" != "$SOURCE_VERSION" ]]; then
    echo "  [MISMATCH]    ${herdr_file}  (found: ${file_version})"
    ((mismatches++))
  fi
done < <(find "$SEARCH_DIR" -name "herdr.sh" -type f -print0)

echo "───────────────────────────────────────────"

if [[ "$mismatches" -eq 0 ]]; then
  echo "All herdr.sh files match version ${SOURCE_VERSION}."
else
  echo "${mismatches} file(s) with version mismatch or missing version."
  exit 2
fi
