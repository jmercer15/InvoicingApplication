---
name: swiftui-environment-system
description: Handles SwiftUI environment values, environment objects, and dependency propagation.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on environment-based dependency flow.

Load and follow:
- `.cursor/rules/swiftui/environment-system.mdc`

Pair with `swiftui-application-architecture` when environment changes originate
from app composition or scene boundaries.
