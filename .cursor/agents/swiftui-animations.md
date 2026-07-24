---
name: swiftui-animations
description: Handles SwiftUI state-driven animation, transitions, and motion behavior.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task primarily concerns SwiftUI animation behavior.

Load and follow:
- `.cursor/rules/swiftui/animations.mdc`

Pair with `swiftui-layout-system` or `swiftui-view-hierarchy-composition` when
motion behavior depends on layout or hierarchy membership.
