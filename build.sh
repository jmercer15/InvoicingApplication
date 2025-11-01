#!/bin/bash

# Build script for InvoicingApplication
# This script ensures consistent build settings for local Swift packages

echo "🔧 Configuring build settings for local Swift packages..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ~/Library/Developer/Xcode/DerivedData/InvoicingApplication*
rm -rf ~/Library/Caches/org.swift.swiftpm

# Resolve package dependencies
echo "📦 Resolving package dependencies..."
xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -resolvePackageDependencies

# Build with explicit modules disabled
echo "🏗️  Building with explicit modules disabled..."
xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO \
  build

echo "✅ Build completed!"
