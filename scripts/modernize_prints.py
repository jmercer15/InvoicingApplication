#!/usr/bin/env python3
import os
import re

def modernize_prints_in_file(fpath):
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()

    # Determine appropriate logger
    if "Migration" in fpath or "Migrations" in fpath:
        logger_name = "Logger.migration"
    elif "Calendar" in fpath or "EventKit" in fpath:
        logger_name = "Logger.calendar"
    elif "Import" in fpath or "Export" in fpath:
        logger_name = "Logger.importExport"
    elif "Automation" in fpath or "TravelCharge" in fpath or "NDIS" in fpath:
        logger_name = "Logger.automation"
    elif "Billing" in fpath or "Invoice" in fpath:
        logger_name = "Logger.billing"
    elif "Client" in fpath or "Payee" in fpath or "Relationships" in fpath:
        logger_name = "Logger.clients"
    else:
        logger_name = "Logger.data"

    lines = content.splitlines()
    modified = False
    new_lines = []

    print_pattern = re.compile(r"^(\s*)print\((.*)\)$")

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            new_lines.append(line)
            continue

        match = print_pattern.match(line)
        if match:
            indent = match.group(1)
            arg = match.group(2)
            # Decide log level based on content
            if "⚠️" in arg or "warning" in arg.lower() or "error" in arg.lower():
                level = "warning"
            elif "❌" in arg or "failed" in arg.lower():
                level = "error"
            elif "debug" in arg.lower() or "determining" in arg.lower():
                level = "debug"
            else:
                level = "info"

            # Check if arg is a string literal or formatted string
            new_line = f"{indent}{logger_name}.{level}({arg})"
            new_lines.append(new_line)
            modified = True
        else:
            new_lines.append(line)

    if modified:
        # Check if import Core is present
        full_text = "\n".join(new_lines) + "\n"
        if "import Core" not in full_text and not fpath.startswith("./Packages/Core") and not fpath.startswith("Packages/Core"):
            # insert import Core at the top
            full_text = "import Core\n" + full_text

        with open(fpath, "w", encoding="utf-8") as f:
            f.write(full_text)
        print(f"Modernized prints in: {fpath}")

def run():
    with open("artifacts/modernization_locations_catalog.json") as f:
        import json
        data = json.load(f)

    by_file = set(p["file"] for p in data["residual_prints"])
    for fpath in sorted(by_file):
        # Skip test files
        if "Tests" in fpath or "Test" in fpath:
            continue
        modernize_prints_in_file(fpath)

if __name__ == "__main__":
    run()
