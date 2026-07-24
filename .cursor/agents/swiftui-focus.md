---
name: swiftui-focus
description: Handles SwiftUI focus chains, keyboard-first workflows, and focus synchronization.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on focus management.

Load and follow:
- `.cursor/rules/swiftui/focus.mdc`

Pair with `swiftui-input-events`, `swiftui-search`, or `swiftui-tables` when
focus behavior is tied to keyboard handling or multicolumn views.
