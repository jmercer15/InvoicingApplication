---
name: swiftui-system-events
description: Handles SwiftUI URLs, activities, background tasks, and external system events.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on system-driven app events.

Load and follow:
- `.cursor/rules/swiftui/system-events.mdc`

Pair with `swiftdata-synchronization` or `swiftdata-change-tracking` when
system events drive sync or persistence updates.
