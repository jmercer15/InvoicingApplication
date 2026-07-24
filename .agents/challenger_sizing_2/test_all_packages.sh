#!/bin/bash
set -e

PACKAGES=(
    "Core"
    "Data"
    "SharedUI"
    "AppShell"
    "Feature.BillingHub"
    "Feature.Clients"
    "Feature.InvoiceTemplateEditor"
    "Feature.Invoices"
    "Feature.NDIS"
    "Feature.Settings"
)

FAILED=()

for pkg in "${PACKAGES[@]}"; do
    path="Packages/$pkg"
    if [ -d "$path/Tests" ]; then
        echo "========================================"
        echo "Testing package: $pkg"
        echo "========================================"
        if ! swift test --package-path "$path"; then
            echo "ERROR: Package $pkg failed tests!"
            FAILED+=("$pkg")
        else
            echo "SUCCESS: Package $pkg passed tests."
        fi
    else
        echo "Skipping $pkg (no Tests directory)"
    fi
done

echo "========================================"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "ALL PACKAGE TESTS PASSED CLEANLY!"
    exit 0
else
    echo "THE FOLLOWING PACKAGES FAILED TESTS: ${FAILED[*]}"
    exit 1
fi
