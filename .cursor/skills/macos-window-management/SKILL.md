# Skill: macos-window-management

Use this skill when implementing new windows, settings panes, or multi-window support in a macOS SwiftUI application.

## When To Use This Skill

- Creating a new secondary window, panel, or utility view.
- Adding application-wide Settings/Preferences window.
- Customizing multi-window behavior or document window scenes.

## macOS Window Management Workflow

Follow these steps sequentially to expand the application's window capabilities:

### Step 1: Identify the Scene Type
- **WindowGroup**: For data-driven, multi-window document paradigms or primary workspaces.
- **Window**: For singular utility panels, status items, or detached tools.
- **Settings**: For application preferences/settings pane.

### Step 2: Implement the Scene Definition
- Navigate to the `@main` App struct.
- Append the new scene definition below the primary `WindowGroup` scene.

### Step 3: Data Binding
- If the new window must display details for a specific model instance, utilize the data-driven `WindowGroup(for: Model.self)` pattern.
- This ensures the macOS window manager handles duplicate requests gracefully by bringing the existing window to the front instead of spawning redundant copies.

### Step 4: Environment Triggers
- In the view that triggers the new window, utilize the `@Environment(\.openWindow)` property wrapper to programmatically launch the new scene:
  ```swift
  @Environment(\.openWindow) private var openWindow
  
  // To trigger:
  openWindow(id: "inspector")
  // Or for data-driven:
  openWindow(value: selectedModelID)
  ```

### Step 5: Keyboard Shortcuts
- Attach appropriate `.keyboardShortcut` modifiers to UI triggers or menu commands to align with standard macOS Human Interface Guidelines (HIG).
