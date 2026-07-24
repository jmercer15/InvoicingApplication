---
name: swiftui-input-events
description: Handles SwiftUI keyboard, hover, command, and hardware input events.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on keyboard, hover, or hardware input.

Load and follow:
- `.cursor/rules/swiftui/input-events.mdc`

Pair with `swiftui-focus` or `swiftui-toolbars-commands-menus` when event
routing crosses focus and command systems.
