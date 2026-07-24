#!/bin/bash
set -e

packages=(
    "Packages/SharedUI"
    "Packages/Feature.Settings"
    "Packages/Core"
    "Packages/Data"
    "Packages/Feature.BillingHub"
    "Packages/Feature.Clients"
    "Packages/Feature.InvoiceTemplateEditor"
    "Packages/Feature.Invoices"
    "Packages/Feature.NDIS"
    "Packages/AppShell"
)

echo "Starting package tests..."

for pkg in "${packages[@]}"; do
    echo "========================================"
    echo "Running tests for $pkg..."
    echo "========================================"
    swift test --package-path "$pkg"
done

echo "All package tests passed successfully!"
