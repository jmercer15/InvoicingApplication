# Color System Guide

This document outlines the comprehensive color system implemented in the InvoicingApplication, which utilizes macOS system colors for optimal adaptation to user preferences and accessibility needs.

## Overview

The color system is designed to:

- **Adapt automatically** to light/dark mode and user accessibility settings
- **Provide depth-based hierarchy** using primary/secondary/tertiary/quaternary/quinary variants
- **Ensure accessibility** by using system-defined colors that meet contrast requirements
- **Maintain consistency** across all UI components

## Core Principles

### 1. System Color Usage

All colors are derived from macOS system colors (`NSColor.*`) to ensure:

- Automatic adaptation to system appearance (light/dark mode)
- Compliance with accessibility guidelines
- Consistency with system UI elements
- Future-proof compatibility with system updates

### 2. Depth-Based Hierarchy

UI elements use a 5-level depth hierarchy:

- **Primary** - Deepest level (main backgrounds)
- **Secondary** - Elevated content areas (cards, panels)
- **Tertiary** - More elevated areas (modals, popovers)
- **Quaternary** - Highest elevation (tooltips, overlays)
- **Quinary** - Maximum elevation (floating elements)

## Color Categories

### Background Colors

```swift
Color.primarySurface       // Primary surface - main content areas
Color.secondarySurface     // Secondary surface - elevated content areas
Color.tertiarySurface      // Tertiary surface - more elevated areas
Color.quaternarySurface    // Quaternary surface - highest elevation
Color.quinarySurface       // Quinary surface - maximum elevation
```

### Fill Colors

```swift
Color.primaryFill          // Primary fill - standard UI elements
Color.secondaryFill        // Secondary fill - slightly elevated elements
Color.tertiaryFill         // Tertiary fill - more elevated elements
Color.quaternaryFill       // Quaternary fill - highly elevated elements
Color.quinaryFill          // Quinary fill - maximum elevation elements
```

### Text Colors

```swift
Color.primaryText          // Primary text color
Color.secondaryText        // Secondary text color
Color.tertiaryText         // Tertiary text color
Color.quaternaryText       // Quaternary text color
Color.quinaryText          // Quinary text color
```

### System Colors

All standard system colors are available:

```swift
Color(NSColor.systemRed)
Color(NSColor.systemGreen)
Color(NSColor.systemBlue)
Color(NSColor.systemOrange)
Color(NSColor.systemYellow)
Color(NSColor.systemBrown)
Color(NSColor.systemPink)
Color(NSColor.systemPurple)
Color(NSColor.systemTeal)
Color(NSColor.systemIndigo)
Color(NSColor.systemMint)
Color(NSColor.systemCyan)
Color(NSColor.systemGray)
```

### Control Colors

```swift
Color.primaryControl       // Standard control color
Color.controlText          // Control text color
Color.selectedControl      // Selected control color
Color.selectedControlText  // Selected control text color
Color.controlAccent        // Control accent color
```

### Interactive Elements

```swift
Color.linkColor            // Link color
Color.placeholderText      // Placeholder text color
Color.hoverHighlight       // Hover highlight color
```

## Usage Guidelines

### 1. Background/Fill Selection

Choose the appropriate depth level based on your UI hierarchy:

```swift
// Main content area
.background(Color.primarySurface)

// Card or panel
.background(Color.secondarySurface)

// Modal or popover
.background(Color.tertiarySurface)

// Tooltip or overlay
.background(Color.quaternarySurface)
```

### 2. Text Color Selection

Match text colors to their background depth:

```swift
// Primary text on main surfaces
.foregroundColor(Color.primaryText)

// Secondary text for less important information
.foregroundColor(Color.secondaryText)

// Tertiary text for subtle information
.foregroundColor(Color.tertiaryText)
```

### 3. Status Colors

Use system colors for status indicators:

```swift
// Success states
.foregroundColor(Color.successColor)  // or Color(NSColor.systemGreen)

// Warning states
.foregroundColor(Color.warningColor)  // or Color(NSColor.systemOrange)

// Error states
.foregroundColor(Color(NSColor.systemRed))

// Information states
.foregroundColor(Color.infoColor)     // or Color(NSColor.systemBlue)
```

## Migration from Hard-coded Colors

### Before (❌ Don't do this)

```swift
.background(Color.black)
.foregroundColor(Color.white)
.background(Color(red: 0.2, green: 0.4, blue: 0.8))
.background(Color(hex: "FF0000"))
```

### After (✅ Do this)

```swift
.background(Color.primarySurface)
.foregroundColor(Color.primaryText)
.background(Color(NSColor.systemBlue))
.background(Color(NSColor.systemRed))
```

## Accessibility Benefits

1. **Automatic Contrast**: System colors automatically adjust for accessibility needs
2. **High Contrast Mode**: Colors adapt when users enable high contrast mode
3. **Color Blind Support**: System colors are designed to work with color vision differences
4. **Reduced Motion**: Respects user preferences for reduced motion and transparency

## Testing

To test the color system:

1. **Light Mode**: Test in System Preferences > General > Appearance > Light
2. **Dark Mode**: Test in System Preferences > General > Appearance > Dark
3. **High Contrast**: Test in System Preferences > Accessibility > Display > Increase contrast
4. **Color Filters**: Test with various color vision accessibility features

## Legacy Support

The system maintains backward compatibility with existing color references:

- `Color.elevatedSurface` maps to `Color.secondarySurface`
- `Color.activeSurface` remains available for active states

## Best Practices

1. **Always use system colors** instead of hard-coded values
2. **Choose appropriate depth levels** for your UI hierarchy
3. **Test in both light and dark modes** during development
4. **Use system colors for status indicators** to ensure accessibility
5. **Avoid mixing depth levels** unless there's a clear visual hierarchy reason

## Examples

### Card Component

```swift
struct CardView: View {
    var body: some View {
        VStack {
            Text("Card Title")
                .foregroundColor(Color.primaryText)
            Text("Card subtitle")
                .foregroundColor(Color.secondaryText)
        }
        .padding()
        .background(Color.secondarySurface)
        .cornerRadius(8)
        .shadow(color: Color.subtleShadow, radius: 4, x: 0, y: 2)
    }
}
```

### Status Badge

```swift
struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .foregroundColor(Color.accentText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor)
            )
    }

    private var statusColor: Color {
        switch status.lowercased() {
        case "active": return Color.successColor
        case "warning": return Color.warningColor
        case "error": return Color(NSColor.systemRed)
        default: return Color(NSColor.systemGray)
        }
    }
}
```

This color system ensures your application will look great and remain accessible across all user preferences and system configurations.
