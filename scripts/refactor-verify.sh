#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/refactor-verify.XXXXXX")"
trap 'rm -rf "${LOG_DIR}"' EXIT
STEP_NUMBER=0
APP_DERIVED_DATA="${ROOT_DIR}/BuildData/RefactorVerification"
APP_BUNDLE="${APP_DERIVED_DATA}/Build/Products/Debug/InvoicingApplication.app"

check_repository_warnings() {
  local log_file="$1"
  local owned_warnings
  owned_warnings="$(awk -v root="${ROOT_DIR}" '
    index($0, "warning:") && index($0, root) &&
    !index($0, "/.build/") &&
    !index($0, "/BuildData/") &&
    !index($0, "/SourcePackages/checkouts/") { print }
  ' "${log_file}")"

  if [[ -n "${owned_warnings}" ]]; then
    echo "Repository-owned warnings detected:" >&2
    echo "${owned_warnings}" >&2
    return 1
  fi

  local checkout_warning_count
  checkout_warning_count="$(awk '
    index($0, "warning:") &&
    (index($0, "/.build/checkouts/") || index($0, "/SourcePackages/checkouts/")) { count++ }
    END { print count + 0 }
  ' "${log_file}")"
  if (( checkout_warning_count > 0 )); then
    echo "==> Ignored ${checkout_warning_count} third-party checkout warning(s)"
  fi
}

run_step() {
  local label="$1"
  shift
  echo "==> ${label}"
  local start
  start="$(date +%s)"
  STEP_NUMBER=$((STEP_NUMBER + 1))
  local log_file="${LOG_DIR}/step-${STEP_NUMBER}.log"
  "$@" 2>&1 | tee "${log_file}"
  check_repository_warnings "${log_file}"
  local end
  end="$(date +%s)"
  echo "==> ${label} completed in $((end - start))s"
}

verify_app_runtime_linkage() {
  local binaries=(
    "${APP_BUNDLE}/Contents/MacOS/InvoicingApplication"
    "${APP_BUNDLE}/Contents/MacOS/InvoicingApplication.debug.dylib"
  )

  local binary
  for binary in "${binaries[@]}"; do
    if [[ ! -x "${binary}" ]]; then
      echo "Missing built app binary: ${binary}" >&2
      return 1
    fi
    if otool -L "${binary}" | grep -q '@rpath/Testing\.framework'; then
      echo "Production app binary links Swift Testing: ${binary}" >&2
      return 1
    fi
  done

  echo "Production app binaries contain no Swift Testing runtime dependency."
}

run_swiftlint() {
  (
    cd "${ROOT_DIR}"
    swiftlint lint --strict --quiet --no-cache \
      --config .swiftlint.yml \
      --baseline .swiftlint-baseline.json \
      InvoicingApplication Packages
  )
}

run_step "Swift LOC / pattern counts" bash "${ROOT_DIR}/scripts/swift-repo-metrics.sh"
run_step "Architecture guardrails" bash "${ROOT_DIR}/scripts/architecture-check.sh"
run_step "SwiftLint" run_swiftlint

# Core & Infrastructure Packages
run_step "Core tests" swift test --package-path "${ROOT_DIR}/Packages/Core"
run_step "DataInterfaces tests" swift test --package-path "${ROOT_DIR}/Packages/DataInterfaces"
run_step "PersistenceModels build" swift build --package-path "${ROOT_DIR}/Packages/PersistenceModels"
run_step "Data tests" swift test --package-path "${ROOT_DIR}/Packages/Data"

# UI Foundation Packages
run_step "SharedUI tests" swift test --package-path "${ROOT_DIR}/Packages/SharedUI"
run_step "WorkspaceUI tests" swift test --package-path "${ROOT_DIR}/Packages/WorkspaceUI"

# Feature Packages
run_step "Feature.Settings tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.Settings"
run_step "Feature.NDIS tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.NDIS"
run_step "Feature.BillingHub tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.BillingHub"
run_step "Feature.Clients tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.Clients"
run_step "Feature.Calendar tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.Calendar"
run_step "Feature.Invoices tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.Invoices"
run_step "Feature.InvoiceTemplateEditor tests" swift test --package-path "${ROOT_DIR}/Packages/Feature.InvoiceTemplateEditor"

# Application Shell Package
run_step "AppShell tests" swift test --package-path "${ROOT_DIR}/Packages/AppShell"

# Root macOS Application Tests
run_step "App tests" xcodebuild \
  -project "${ROOT_DIR}/InvoicingApplication.xcodeproj" \
  -scheme InvoicingApplication \
  -configuration Debug \
  -derivedDataPath "${APP_DERIVED_DATA}" \
  -destination 'platform=macOS' \
  test
run_step "App runtime linkage" verify_app_runtime_linkage
