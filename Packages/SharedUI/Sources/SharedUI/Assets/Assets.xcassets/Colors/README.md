# Color Asset Catalog

This document describes the comprehensive color asset catalog for the InvoicingApplication. All colors are organized into logical categories and can be accessed using `Color("ColorName")` syntax.

## Color Categories

### 1. Primary Colors

- **Primary** - System control accent color (adapts to user's system preference)

### 2. Status Colors

Used for indicating different states and statuses throughout the application:

- **Active** - Green color for active/completed items
- **Inactive** - Orange color for inactive/pending items
- **Archived** - Gray color for archived items
- **Draft** - Blue color for draft/planned items
- **Cancelled** - Red color for cancelled/error items
- **Blue70** - Blue with 70% opacity for buttons and highlights
- **Red70** - Red with 70% opacity for error states
- **Orange20** - Orange with 20% opacity for warnings
- **Green20** - Green with 20% opacity for success states

### 3. Entity Colors

Used for categorizing different entity types:

- **Client** - Blue color for client entities
- **Payee** - Indigo color for payee/provider entities
- **PlanManager** - Purple color for plan manager entities
- **Service** - Teal color for service entities
- **Invoice** - Green color for invoice entities

### 4. UI Colors

System-adaptive colors for user interface elements:

- **Background** - Window background color
- **Surface** - Control background color
- **Border** - Separator color
- **Text** - Label color
- **TextSecondary** - Secondary label color
- **FieldBackground** - Text background color
- **Shadow** - Black with 15% opacity for shadows
- **GlassBackground** - Black with 30% opacity for glass morphism
- **GlassHover** - White with 5% opacity for glass hover effects
- **GlassBorder** - White with 10% opacity for glass borders
- **MainContentBackground** - Dark gray (0.11, 0.11, 0.13) used throughout the app

### 5. Opacity Variations

Commonly used opacity variations for consistent styling:

**White Opacity:**

- **White05** - White with 5% opacity for subtle backgrounds
- **White10** - White with 10% opacity for hover states
- **White15** - White with 15% opacity for glass morphism
- **White20** - White with 20% opacity for overlays
- **White30** - White with 30% opacity for borders

**Black Opacity:**

- **Black30** - Black with 30% opacity for shadows
- **Black50** - Black with 50% opacity for overlays

**Gray Opacity:**

- **Gray10** - Gray with 10% opacity for subtle backgrounds
- **Gray20** - Gray with 20% opacity for borders
- **Gray30** - Gray with 30% opacity for backgrounds

### 6. Common Hex Colors

Frequently used hex colors for consistent UI styling:

- **Indigo** - #3949AB - Used in buttons and UI elements
- **LightGray** - #E5E7EB - Used for borders and headers
- **VeryLightGray** - #F9FAFB - Used for backgrounds
- **LightIndigo** - #E0E7FF - Used for button backgrounds
- **LightBlue** - #DBEAFE - Used for backgrounds
- **HoverIndigo** - #C7D2FE - Used for hover states
- **DarkIndigo** - #303F9F - Used for gradients
- **Blue** - #3F51B5 - Used in gradients
- **DarkBlue** - #283593 - Used in gradients

### 7. Calendar Colors

Specialized colors for calendar functionality:

- **Travel** - Specific blue color for travel sessions

#### Google Calendar Colors

Complete set of Google Calendar standard colors:

- **Lavender** - Soft purple
- **Sage** - Muted green
- **Grape** - Deep purple
- **Flamingo** - Pink
- **Banana** - Yellow
- **Tangerine** - Orange
- **Peacock** - Blue
- **Graphite** - Gray
- **Blueberry** - Dark blue
- **Basil** - Green
- **Tomato** - Red

### 8. Decorative Colors

Premium and decorative color options:

- **PremiumGold** - Metallic gold color
- **PremiumSilver** - Metallic silver color

## Usage Examples

### Basic Usage

```swift
// Using color assets
Text("Active Item")
    .foregroundColor(Color("Active"))

Button("Submit") {
    // Action
}
.background(Color("Primary"))
```

### Opacity Variations

```swift
// Using opacity variations
RoundedRectangle(cornerRadius: 12)
    .fill(Color("White15"))
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color("White30"), lineWidth: 1)
    )
```

### Common Hex Colors

```swift
// Using common hex colors
Button("Action") {
    // Action
}
.background(Color("Indigo"))
.foregroundColor(.white)
```

### Status-Based Coloring

```swift
// Dynamic status coloring
let statusColor = Color(status == "active" ? "Active" : "Inactive")
Text(status)
    .foregroundColor(statusColor)
```

### Entity Type Coloring

```swift
// Entity-specific colors
let entityColor = Color(entityType == "client" ? "Client" : "Payee")
Circle()
    .fill(entityColor)
```

### Glass Morphism

```swift
// Glass morphism styling
RoundedRectangle(cornerRadius: 12)
    .fill(Color("GlassBackground"))
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color("GlassBorder"), lineWidth: 1)
    )
```

### Google Calendar Integration

```swift
// Google Calendar color mapping
let calendarColor = Color("Lavender") // or any other Google color
```

## Benefits

1. **Consistency** - All colors are centrally managed
2. **System Adaptation** - UI colors automatically adapt to light/dark mode
3. **Maintainability** - Easy to update colors across the entire application
4. **Accessibility** - System colors respect accessibility settings
5. **Performance** - Color assets are optimized and cached by the system

## Migration Guide

To migrate from hardcoded colors to color assets:

1. Replace `Color.blue` with `Color("Primary")` or `Color("Draft")`
2. Replace `Color.red` with `Color("Cancelled")`
3. Replace `Color.green` with `Color("Active")`
4. Replace `Color.orange` with `Color("Inactive")`
5. Replace `Color.gray` with `Color("Archived")`
6. Replace `Color.white.opacity(0.1)` with `Color("White10")`
7. Replace `Color.black.opacity(0.3)` with `Color("Black30")`
8. Replace `Color(hex: "#3949AB")` with `Color("Indigo")`

## Best Practices

1. Always use color assets instead of hardcoded colors
2. Use semantic color names (e.g., "Active" instead of "Green")
3. Leverage system colors for UI elements to ensure proper adaptation
4. Use entity colors consistently across the application
5. Test colors in both light and dark modes
6. Use opacity variations for consistent styling patterns
7. Prefer color assets over hex strings for better maintainability
