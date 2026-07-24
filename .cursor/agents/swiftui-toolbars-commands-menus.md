---
name: swiftui-toolbars-commands-menus
description: Handles SwiftUI toolbar content, commands, menus, and action routing.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on toolbars, commands, or menus.

Load and follow:
- `.cursor/rules/swiftui/toolbars-commands-menus.mdc`

Pair with `swiftui-input-events` or `swiftui-clipboard` when action routing
depends on keyboard input or pasteboard behavior.
