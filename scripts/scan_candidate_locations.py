#!/usr/bin/env python3
import os
import re
import json
from collections import defaultdict

def scan_all_candidates(root_dir="."):
    sources = []
    for r, d, files in os.walk(root_dir):
        if any(p in r for p in ["/.build", "/build", "/BuildData", "/artifacts", "/.git"]):
            continue
        for f in files:
            if f.endswith(".swift"):
                sources.append(os.path.normpath(os.path.join(r, f)))
    sources.sort()

    candidates = {
        "scroll_edge_effect": [],
        "inspector_candidates": [],
        "batch_delete_candidates": [],
        "residual_prints": [],
        "debounce_timer_candidates": [],
        "app_entity_candidates": []
    }

    scroll_re = re.compile(r"\b(ScrollView|List|Table)\s*[\(\{]")
    sheet_re = re.compile(r"\.sheet\s*\(\s*isPresented:\s*\$([A-Za-z0-9_]+)")
    delete_loop_re = re.compile(r"for\s+([A-Za-z0-9_]+)\s+in\s+([A-Za-z0-9_]+)\s*\{\s*([A-Za-z0-9_]*context|\bself\b)?\.delete\(")
    print_re = re.compile(r"^\s*print\(", re.MULTILINE)
    debounce_re = re.compile(r"debounce|Task\.sleep|asyncAfter", re.IGNORECASE)

    for path in sources:
        is_test = "Tests" in path or "Test" in path
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        content = "".join(lines)

        # 1. Scroll edge effect candidates (ScrollView / List in View files)
        if not is_test:
            for idx, line in enumerate(lines, start=1):
                if re.search(scroll_re, line):
                    stripped = line.strip()
                    # Check if file has scrollEdgeEffectStyle or standardPanelScrollEdgeEffect
                    has_effect = "scrollEdgeEffect" in content or "standardPanelScrollEdgeEffect" in content
                    candidates["scroll_edge_effect"].append({
                        "file": path,
                        "line": idx,
                        "content": stripped,
                        "has_effect": has_effect
                    })

        # 2. Inspector candidates (.sheet presenting details/editor/inspector)
        if not is_test:
            for idx, line in enumerate(lines, start=1):
                match = sheet_re.search(line)
                if match:
                    binding = match.group(1)
                    # Check context around sheet
                    context_snippet = "".join(lines[idx-1:min(len(lines), idx+10)]).strip()
                    candidates["inspector_candidates"].append({
                        "file": path,
                        "line": idx,
                        "binding": binding,
                        "context": context_snippet[:200]
                    })

        # 3. Batch delete candidates (loop calling context.delete)
        for idx, line in enumerate(lines, start=1):
            if "context.delete(" in line or "modelContext.delete(" in line:
                # check if inside a loop
                surrounding = "".join(lines[max(0, idx-5):min(len(lines), idx+3)])
                if "for " in surrounding:
                    candidates["batch_delete_candidates"].append({
                        "file": path,
                        "line": idx,
                        "snippet": surrounding.strip()
                    })

        # 4. Residual print statements in production code
        if not is_test:
            for idx, line in enumerate(lines, start=1):
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
                    continue
                if print_re.match(line):
                    candidates["residual_prints"].append({
                        "file": path,
                        "line": idx,
                        "content": stripped
                    })

        # 5. Debounce / Timing candidates
        for idx, line in enumerate(lines, start=1):
            if re.search(debounce_re, line):
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("/*"):
                    continue
                candidates["debounce_timer_candidates"].append({
                    "file": path,
                    "line": idx,
                    "content": stripped,
                    "is_test": is_test
                })

    return candidates

if __name__ == "__main__":
    candidates = scan_all_candidates(".")
    
    print("\n=== SCAN REPORT: CODEBASE MODERNIZATION LOCATIONS ===")
    print(f"1. ScrollView/List View Containers: {len(candidates['scroll_edge_effect'])} locations")
    print(f"2. Modal Sheets / Drawer Presentations: {len(candidates['inspector_candidates'])} locations")
    print(f"3. Deletion Loop Candidates (SwiftData Batch delete targets): {len(candidates['batch_delete_candidates'])} locations")
    print(f"4. Production Residual print() Statements: {len(candidates['residual_prints'])} locations")
    print(f"5. Debounce & Async Timing Points: {len(candidates['debounce_timer_candidates'])} locations")

    # Write detailed artifact
    with open("artifacts/modernization_locations_catalog.json", "w", encoding="utf-8") as f:
        json.dump(candidates, f, indent=2)
    print("\nSaved full catalog to artifacts/modernization_locations_catalog.json")
