#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT_DIR/.bin:$PATH"
FAILED=0

if ! command -v rg &>/dev/null; then
  echo "❌ Error: ripgrep (rg) is required but not installed." >&2
  exit 1
fi


echo "==> Checking forbidden AppShell imports in feature packages"
if rg -n "^\\s*import\\s+AppShell\\b" \
  "${ROOT_DIR}/Packages" \
  --glob "Feature.*/*.swift" \
  --glob "Feature.*/**/*.swift" 2>/dev/null; then
  echo "❌ Forbidden feature imports of AppShell detected."
  FAILED=1
else
  echo "✅ No forbidden AppShell imports in feature packages."
fi

echo
echo "==> Checking Swift Testing isolation from production targets"
if rg -n "^\s*import\s+Testing\b" \
  "${ROOT_DIR}/Packages" \
  --glob "**/Sources/**/*.swift" 2>/dev/null | while read -r match; do
  case "$match" in
    *"/Packages/Core/Sources/CoreTesting/"*)
      continue
      ;;
    *)
      echo "$match"
      ;;
  esac
done | grep -q "."; then
  echo "❌ Swift Testing imported by production source. Move test utilities into CoreTesting."
  FAILED=1
else
  echo "✅ Swift Testing remains isolated to CoreTesting and test targets."
fi

echo
echo "==> Checking direct workspaceStandardServicesEnvironment callsites"
if rg -n "workspaceStandardServicesEnvironment\\(" "${ROOT_DIR}"/Packages --glob "*.swift" | while read -r match; do
  case "$match" in
    *"/Packages/AppShell/Sources/AppShell/App/Composition/AppDependencyInjection.swift"*|*"/Packages/WorkspaceUI/Sources/WorkspaceUI/WorkspaceStandardServicesInjection.swift"*)
      continue
      ;;
    *)
      echo "$match"
      ;;
  esac
done | grep -q "."; then
  echo "❌ workspaceStandardServicesEnvironment used outside the expected bridge point."
  FAILED=1
else
    echo "✅ workspaceStandardServicesEnvironment usage constrained to bridge points."
fi

echo
echo "==> Checking unsafe persistent-identifier materialization"
if rg -n "self\\[[^]]+, as:|\\.model\\(for:" \
  "${ROOT_DIR}/Packages" \
  --glob "*.swift" \
  --glob "!**/Tests/**" 2>/dev/null; then
  echo "❌ Direct PersistentIdentifier materialization detected. Stale identifiers can trap; use a bounded FetchDescriptor."
  FAILED=1
else
  echo "✅ ModelActor identifier resolution uses safe fetches."
fi

echo
echo "==> Checking feature-owned ModelContainer creation"
if rg -n "ModelContainer\\(" \
  "${ROOT_DIR}"/Packages/Feature.*/Sources \
  --glob "*.swift" \
  --glob "!**/*Preview*.swift" 2>/dev/null; then
  echo "❌ Feature source creates its own ModelContainer outside preview support."
  FAILED=1
else
  echo "✅ Production ModelContainer ownership stays in composition/data layers."
fi

echo
echo "==> Checking workspace search ownership"
if rg -n "\\.searchable\\s*\\(" \
  "${ROOT_DIR}/Packages/AppShell/Sources" \
  "${ROOT_DIR}"/Packages/Feature.*/Sources \
  --glob "*.swift" 2>/dev/null | while read -r match; do
  case "$match" in
    *"/Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceSearchHost.swift:"*)
      continue
      ;;
    *)
      echo "$match"
      ;;
  esac
done | grep -q "."; then
  echo "❌ Workspace feature registered its own .searchable modifier. One window-level owner is required on macOS."
  FAILED=1
else
  echo "✅ Workspace search stays owned by WorkspaceSearchHost."
fi

echo
echo "==> Checking invoice template preference ownership"
if rg -n "InvoiceTemplatePreferenceStore" \
  "${ROOT_DIR}/Packages/Feature.InvoiceTemplateEditor/Sources" \
  --glob "*.swift" 2>/dev/null | while read -r match; do
  case "$match" in
    *"/Data/InvoiceTemplatePreferenceStore.swift:"*|*"/InvoiceEditorStore.swift:"*|*"/Views/InvoiceRootView.swift:"*)
      continue
      ;;
    *)
      echo "$match"
      ;;
  esac
done | grep -q "."; then
  echo "❌ Template preferences used outside template workspace or invoice-creation boundary."
  FAILED=1
else
  echo "✅ Template preferences stay isolated from persisted invoice decoding and rendering."
fi

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo
echo "✅ Architecture check completed."
