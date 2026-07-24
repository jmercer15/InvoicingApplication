---
name: swiftui-application-architecture
description: Handles SwiftUI app entry points, scenes, windows, and root-view composition.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when editing `App` types, scene structure, app composition,
or root-view wiring.

Load and follow:
- `.cursor/rules/swiftui/application-architecture.mdc`

Pair with `swiftdata-storage-infrastructure` when app composition also wires
persistence containers or contexts.
