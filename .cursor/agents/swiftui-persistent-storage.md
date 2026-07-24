---
name: swiftui-persistent-storage
description: Handles SwiftUI persisted UI state such as AppStorage and SceneStorage.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on persisted UI state.

Load and follow:
- `.cursor/rules/swiftui/persistent-storage.mdc`

Pair with `swiftdata-persistence-lifecycle` only when the task crosses from UI
storage into real data persistence semantics.
