#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_step() {
  local label="$1"
  shift
  echo "==> ${label}"
  local start
  start="$(date +%s)"
  "$@"
  local end
  end="$(date +%s)"
  echo "==> ${label} completed in $((end - start))s"
}

run_step "Swift LOC / pattern counts" bash "${ROOT_DIR}/scripts/swift-repo-metrics.sh"
run_step "Architecture guardrails" bash "${ROOT_DIR}/scripts/architecture-check.sh"

run_step "SharedUI tests" swift test --package-path "${ROOT_DIR}/Packages/SharedUI"
run_step "Feature.Settings tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.Settings"
run_step "Feature.Calendar build" swift build --package-path "${ROOT_DIR}/Packages/Feature.Calendar"
run_step "App Debug build" xcodebuild \
  -project "${ROOT_DIR}/InvoicingApplication.xcodeproj" \
  -scheme InvoicingApplication \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
