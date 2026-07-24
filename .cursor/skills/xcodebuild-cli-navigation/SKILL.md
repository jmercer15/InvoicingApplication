# Skill: xcodebuild-cli-navigation

Use this skill to navigate the XcodeBuildMCP CLI, execute builds, run tests, and analyze compiler errors.

## When To Use This Skill

- Running incremental compilation checks via command line tools.
- Invoking builds/tests autonomously inside the agent workspace.
- Fetching and parsing build failure diagnostics.

## XcodeBuildMCP CLI Usage Guide

You are utilizing the `xcodebuildmcp` CLI to interact with the local Xcode build environment.

### Step 1: Listing Tools
- To see all available capabilities, execute the tool listing:
  ```bash
  xcodebuildmcp tools
  ```

### Step 2: Building for Simulator
- To compile the application, use the precise command format matching your project's target:
  ```bash
  xcodebuildmcp simulator build --scheme <SchemeName> --project-path ./[ProjectName].xcodeproj
  ```

### Step 3: Log Capture and Diagnostics
- The CLI operates a stateful workspace daemon. 
- If an error occurs during a build, immediately capture the workspace logs for analysis before proposing code modifications.
- Parse structured diagnostics to find precise file paths, line numbers, and compiler error codes.
