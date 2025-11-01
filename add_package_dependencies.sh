#!/bin/bash

# Script to add Swift package dependencies to the main Xcode project
# This script provides instructions for manually adding the packages

echo "Adding Swift Package Dependencies to InvoicingApplication"
echo "========================================================"
echo ""

echo "The following local Swift packages need to be added to the main Xcode project:"
echo ""
echo "1. Core (./Packages/Core)"
echo "2. Data (./Packages/Data)" 
echo "3. SharedUI (./Packages/SharedUI)"
echo "4. Feature.Calendar (./Packages/Feature.Calendar)"
echo "5. Feature.BillingHub (./Packages/Feature.BillingHub)"
echo "6. Feature.Clients (./Packages/Feature.Clients)"
echo "7. Feature.Invoices (./Packages/Feature.Invoices)"
echo "8. Feature.Settings (./Packages/Feature.Settings)"
echo ""

echo "To add these packages manually in Xcode:"
echo "1. Open InvoicingApplication.xcodeproj in Xcode"
echo "2. Select the InvoicingApplication project in the navigator"
echo "3. Select the InvoicingApplication target"
echo "4. Go to the 'General' tab"
echo "5. In the 'Frameworks, Libraries, and Embedded Content' section, click the '+' button"
echo "6. Click 'Add Package Dependency...'"
echo "7. Click 'Add Local...'"
echo "8. Navigate to and select each package directory (e.g., ./Packages/Core)"
echo "9. Repeat for all 8 packages"
echo ""

echo "Alternatively, you can use the Package.swift approach:"
echo "1. Open the project in Xcode"
echo "2. File -> Add Package Dependencies"
echo "3. Add each local package by selecting the directory"
echo ""

echo "After adding the packages, the project should build successfully."
echo ""

# Let's also try to build the individual packages to ensure they're ready
echo "Building individual packages to verify they're ready..."
echo ""

cd Packages/Core
echo "Building Core package..."
if swift build; then
    echo "✅ Core package builds successfully"
else
    echo "❌ Core package has build errors"
fi

cd ../Data
echo "Building Data package..."
if swift build; then
    echo "✅ Data package builds successfully"
else
    echo "❌ Data package has build errors"
fi

cd ../SharedUI
echo "Building SharedUI package..."
if swift build; then
    echo "✅ SharedUI package builds successfully"
else
    echo "❌ SharedUI package has build errors"
fi

cd ../Feature.Calendar
echo "Building Feature.Calendar package..."
if swift build; then
    echo "✅ Feature.Calendar package builds successfully"
else
    echo "❌ Feature.Calendar package has build errors"
fi

cd ../Feature.BillingHub
echo "Building Feature.BillingHub package..."
if swift build; then
    echo "✅ Feature.BillingHub package builds successfully"
else
    echo "❌ Feature.BillingHub package has build errors"
fi

cd ../Feature.Clients
echo "Building Feature.Clients package..."
if swift build; then
    echo "✅ Feature.Clients package builds successfully"
else
    echo "❌ Feature.Clients package has build errors"
fi

cd ../Feature.Invoices
echo "Building Feature.Invoices package..."
if swift build; then
    echo "✅ Feature.Invoices package builds successfully"
else
    echo "❌ Feature.Invoices package has build errors"
fi

cd ../Feature.Settings
echo "Building Feature.Settings package..."
if swift build; then
    echo "✅ Feature.Settings package builds successfully"
else
    echo "❌ Feature.Settings package has build errors"
fi

cd ../..
echo ""
echo "Package build verification complete!"
echo ""
echo "Next steps:"
echo "1. Add the packages to the main Xcode project as described above"
echo "2. Build the main application"
echo "3. Test the restructured application"
