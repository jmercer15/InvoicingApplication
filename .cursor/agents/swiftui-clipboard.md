---
name: swiftui-clipboard
description: Handles SwiftUI copy, cut, paste, and pasteboard-backed data exchange.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on clipboard workflows.

Load and follow:
- `.cursor/rules/swiftui/clipboard.mdc`

Pair with `swiftui-toolbars-commands-menus` or `swiftui-drag-and-drop` when the
same interaction surface spans commands or transferable flows.
