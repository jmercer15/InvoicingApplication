#!/usr/bin/env bash
# Aggregate all project Swift sources into one structured text file.
#
# Usage:
#   ./scripts/aggregate-swift-sources.sh
#   ./scripts/aggregate-swift-sources.sh -o artifacts/my-snapshot.txt
#   ./scripts/aggregate-swift-sources.sh --scan-all
#   ./scripts/aggregate-swift-sources.sh --include-tooling
#
# Defaults:
#   - Output: artifacts/swift-codebase-aggregate.txt (under repo root; gitignored)
#   - Sources: git-tracked *.swift only (respects .gitignore)
#   - Excludes: .agents, .trae, .windsurf (duplicate skill trees; use --include-tooling)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${ROOT_DIR}/artifacts/swift-codebase-aggregate.txt"
USE_GIT=1
INCLUDE_TOOLING=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options:"
  echo "  -o, --output PATH     Output file (default: artifacts/swift-codebase-aggregate.txt)"
  echo "  --scan-all            Find all *.swift on disk (not only git-tracked)"
  echo "  --include-tooling     Include .agents, .trae, .windsurf Swift files"
  echo "  -h, --help            Show this help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      [[ $# -ge 2 ]] || { echo "error: $1 requires a path" >&2; exit 2; }
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --scan-all)
      USE_GIT=0
      shift
      ;;
    --include-tooling)
      INCLUDE_TOOLING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Resolve output path relative to repo root when not absolute.
if [[ "${OUTPUT_PATH}" != /* ]]; then
  OUTPUT_PATH="${ROOT_DIR}/${OUTPUT_PATH}"
fi

should_skip_path() {
  local rel="$1"
  if [[ "${INCLUDE_TOOLING}" -eq 0 ]]; then
    case "${rel}" in
      .agents/*|.trae/*|.windsurf/*) return 0 ;;
    esac
  fi
  return 1
}

collect_git_swift_files() {
  git -C "${ROOT_DIR}" ls-files -z 2>/dev/null \
    | while IFS= read -r -d '' path; do
        [[ "${path}" == *.swift ]] || continue
        [[ -f "${ROOT_DIR}/${path}" ]] || continue
        should_skip_path "${path}" && continue
        printf '%s\0' "${path}"
      done
}

collect_find_swift_files() {
  local -a prune_args=()
  prune_args+=(
    \( -path "${ROOT_DIR}/.git" -o -path "${ROOT_DIR}/.build" -o -path "${ROOT_DIR}/DerivedData"
    -o -path "${ROOT_DIR}/build" -o -path "${ROOT_DIR}/*/build" \)
  )
  if [[ "${INCLUDE_TOOLING}" -eq 0 ]]; then
    prune_args+=(
      -o -path "${ROOT_DIR}/.agents" -o -path "${ROOT_DIR}/.trae" -o -path "${ROOT_DIR}/.windsurf"
    )
  fi
  prune_args+=( \) -prune -o -name '*.swift' -type f -print0 )

  find "${ROOT_DIR}" "${prune_args[@]}" | while IFS= read -r -d '' full; do
    local rel="${full#"${ROOT_DIR}/"}"
    should_skip_path "${rel}" && continue
    printf '%s\0' "${rel}"
  done
}

collect_swift_files() {
  if [[ "${USE_GIT}" -eq 1 ]] && git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
    collect_git_swift_files
  else
    collect_find_swift_files
  fi
}

SWIFT_FILES=()
while IFS= read -r -d '' f; do
  SWIFT_FILES+=("$f")
done < <(collect_swift_files | LC_ALL=C sort -z)

if [[ ${#SWIFT_FILES[@]} -eq 0 ]]; then
  echo "error: no Swift files found (try --scan-all?)" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"
tmp_output="$(mktemp "${OUTPUT_PATH}.XXXXXX")"
trap 'rm -f "${tmp_output}"' EXIT

{
  printf '%s\n' "Swift Codebase Aggregate"
  printf 'Generated: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  printf 'Repository: %s\n' "${ROOT_DIR}"
  printf 'Source mode: %s\n' "$([[ "${USE_GIT}" -eq 1 ]] && echo 'git-tracked' || echo 'filesystem scan')"
  printf 'Tooling trees: %s\n' "$([[ "${INCLUDE_TOOLING}" -eq 1 ]] && echo 'included' || echo 'excluded')"
  printf 'Files: %s\n' "${#SWIFT_FILES[@]}"
  printf '%s\n' ""
  printf '%s\n' "TABLE OF CONTENTS"
  printf '%s\n' "--------------------------------------------------------------------------------"
} > "${tmp_output}"

total_lines=0
declare -a line_counts=()

for rel in "${SWIFT_FILES[@]}"; do
  full="${ROOT_DIR}/${rel}"
  count="$(wc -l < "${full}" | tr -d ' ')"
  line_counts+=("${count}")
  total_lines=$((total_lines + count))
  printf '%6d  %s\n' "${count}" "${rel}" >> "${tmp_output}"
done

{
  printf '%s\n' "--------------------------------------------------------------------------------"
  printf 'Total lines: %d\n' "${total_lines}"
  printf '%s\n' ""
} >> "${tmp_output}"

file_index=0
for rel in "${SWIFT_FILES[@]}"; do
  file_index=$((file_index + 1))
  full="${ROOT_DIR}/${rel}"
  lines="${line_counts[$((file_index - 1))]}"

  {
    printf '%s\n' "================================================================================"
    printf 'FILE %d/%d: %s\n' "${file_index}" "${#SWIFT_FILES[@]}" "${rel}"
    printf 'Lines: %s\n' "${lines}"
    printf '%s\n' "================================================================================"
  } >> "${tmp_output}"

  cat "${full}" >> "${tmp_output}"
  printf '\n' >> "${tmp_output}"
done

mv "${tmp_output}" "${OUTPUT_PATH}"
trap - EXIT

bytes="$(wc -c < "${OUTPUT_PATH}" | tr -d ' ')"
echo "Wrote ${#SWIFT_FILES[@]} Swift files (${total_lines} lines, ${bytes} bytes)"
echo "Output: ${OUTPUT_PATH}"
