---
name: swiftui-preferences-system
description: Handles SwiftUI PreferenceKey-based upward communication and measurement propagation.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on preference keys or child-to-parent
communication.

Load and follow:
- `.cursor/rules/swiftui/preferences-system.mdc`

Pair with `swiftui-layout-system` or `swiftui-scroll-views` when preferences
support measurement-driven layout or scroll coordination.
