---
name: swiftui-layout-system
description: Handles SwiftUI layout strategy, alignment, measurement, and adaptive sizing.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task primarily concerns layout behavior.

Load and follow:
- `.cursor/rules/swiftui/layout-system.mdc`

Pair with `swiftui-view-hierarchy-composition` when hierarchy decisions are the
real driver of layout complexity.
