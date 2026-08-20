#!/usr/bin/env python3
import os
import json
from collections import defaultdict

def generate_markdown_catalog():
    with open("artifacts/modernization_locations_catalog.json", "r") as f:
        data = json.load(f)

    lines = []
    lines.append("# Comprehensive Codebase Modernization Targets Catalog\n")
    lines.append("Full inventory of all locations across the InvoicingApplication codebase identified for next-generation Apple platform API and architectural improvements.\n")

    # 1. SwiftData Batch Deletion Opportunities
    lines.append("## 1. SwiftData Batch Deletion Targets (`context.delete(model:where:)`)\n")
    lines.append("Locations currently executing iterative `for ... in ... { context.delete(...) }` loops that can be optimized to single atomic batch delete operations:\n")
    lines.append("| File | Line | Current Iteration Pattern | Proposed Batch Modernization |")
    lines.append("| :--- | :---: | :--- | :--- |")
    for item in data["batch_delete_candidates"]:
        fpath = item["file"]
        line = item["line"]
        snippet = item["snippet"].replace("\n", " ")[:80]
        lines.append(f"| [`{os.path.basename(fpath)}:{line}`](file://{os.path.abspath(fpath)}#L{line}) | {line} | `{snippet}` | `try context.delete(model:where:)` |")
    lines.append("\n---\n")

    # 2. ScrollEdgeEffect Targets
    lines.append("## 2. ScrollView & List Containers (Liquid Glass Scroll Edge Effect)\n")
    lines.append("Views containing primary scroll viewports eligible for `.standardPanelScrollEdgeEffect()`:\n")
    lines.append("| Module | File | Line | View Type | Status |")
    lines.append("| :--- | :--- | :---: | :--- | :---: |")
    for item in data["scroll_edge_effect"]:
        fpath = item["file"]
        line = item["line"]
        parts = fpath.split(os.sep)
        mod = parts[1] if parts[0] == "Packages" else parts[0]
        vtype = item["content"].split("(")[0].split("{")[0].strip()
        status = "✅ Adopted" if item["has_effect"] else "🎯 Target"
        lines.append(f"| `{mod}` | [`{os.path.basename(fpath)}:{line}`](file://{os.path.abspath(fpath)}#L{line}) | {line} | `{vtype}` | {status} |")
    lines.append("\n---\n")

    # 3. Sheet & Inspector Targets
    lines.append("## 3. Modal Sheets & Inspection Drawers (`.inspector(isPresented:)`)\n")
    lines.append("Locations presenting detail views or inspection drawers:\n")
    lines.append("| File | Line | Binding | Presentation Mode |")
    lines.append("| :--- | :---: | :--- | :--- |")
    for item in data["inspector_candidates"]:
        fpath = item["file"]
        line = item["line"]
        binding = item["binding"]
        lines.append(f"| [`{os.path.basename(fpath)}:{line}`](file://{os.path.abspath(fpath)}#L{line}) | {line} | `\${binding}` | `.sheet` / `.inspector` candidate |")
    lines.append("\n---\n")

    # 4. Debounce & Async Timing Points
    lines.append("## 4. Debounce & Async Timing Points (`ContinuousClock` / `Duration`)\n")
    lines.append("Timing and delay points eligible for standardized Clock & Duration primitives:\n")
    lines.append("| Module | File | Line | Snippet |")
    lines.append("| :--- | :--- | :---: | :--- |")
    for item in data["debounce_timer_candidates"]:
        fpath = item["file"]
        line = item["line"]
        parts = fpath.split(os.sep)
        mod = parts[1] if parts[0] == "Packages" else parts[0]
        content = item["content"][:90]
        lines.append(f"| `{mod}` | [`{os.path.basename(fpath)}:{line}`](file://{os.path.abspath(fpath)}#L{line}) | {line} | `{content}` |")
    lines.append("\n---\n")

    # 5. Production Residual print() Statements
    lines.append("## 5. Production Structured Logging Targets (`os.Logger`)\n")
    lines.append("Production source files containing residual `print()` statements migratable to `Logger`:\n")
    by_file = defaultdict(list)
    for item in data["residual_prints"]:
        by_file[item["file"]].append(item["line"])

    lines.append("| File | Module | Residual print() Count | Lines | Suggested Logger Subsystem |")
    lines.append("| :--- | :--- | :---: | :--- | :--- |")
    for fpath, line_nums in sorted(by_file.items(), key=lambda x: -len(x[1])):
        parts = fpath.split(os.sep)
        mod = parts[1] if parts[0] == "Packages" else parts[0]
        lines_str = ", ".join(str(l) for l in line_nums[:6])
        if len(line_nums) > 6:
            lines_str += f" (+{len(line_nums)-6} more)"
        lines.append(f"| [`{os.path.basename(fpath)}`](file://{os.path.abspath(fpath)}#L{line_nums[0]}) | `{mod}` | {len(line_nums)} | {lines_str} | `Logger.data` / `Logger.calendar` |")

    with open("artifacts/codebase_modernization_targets.md", "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("Saved markdown report to artifacts/codebase_modernization_targets.md")

if __name__ == "__main__":
    generate_markdown_catalog()
