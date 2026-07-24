#!/usr/bin/env bash
# Lightweight Swift inventory for refactor verification (no external deps).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Repository root: ${ROOT_DIR}"
echo

swift_files="$(
  find "${ROOT_DIR}" \
    \( -path '*/.build/*' -o -path '*/DerivedData/*' -o -path '*/.git/*' \) -prune -o \
    -name '*.swift' -type f -print | wc -l | tr -d ' '
)"
echo "Swift files (*.swift, excluding .build/DerivedData/.git): ${swift_files}"
echo

echo "Top 20 largest Swift sources by line count (wc -l):"
find "${ROOT_DIR}" \
  \( -path '*/.build/*' -o -path '*/DerivedData/*' -o -path '*/.git/*' \) -prune -o \
  -name '*.swift' -type f -print0 |
  xargs -0 wc -l 2>/dev/null | awk '!/ total$/' | sort -nr | head -20 || true

echo
echo "Pattern counts (grep -RE over *.swift; may include comments/strings):"

count_pattern() {
  local label="$1"
  local pattern="$2"
  local n
  n="$(
    grep -RE "${pattern}" \
      --include='*.swift' \
      --exclude-dir='.build' \
      --exclude-dir='DerivedData' \
      --exclude-dir='.git' \
      "${ROOT_DIR}" 2>/dev/null | wc -l | tr -d ' '
  )"
  echo "  ${label}: ${n}"
}

count_pattern '@Query' '@Query\b'
count_pattern '@Model' '@Model\b'
count_pattern '@ModelActor' '@ModelActor\b'
count_pattern 'ModelContext' '\bModelContext\b'
