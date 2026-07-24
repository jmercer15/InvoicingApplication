import os
import re

directories = [
    "Packages/Feature.Invoices/Sources/Feature_Invoices/Views",
    "Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views",
    "Packages/Feature.Calendar/Sources/Feature_Calendar/Views",
    "Packages/Feature.Settings/Sources/Feature_Settings/Views",
    "Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views",
    "Packages/AppShell/Sources/AppShell"
]

patterns = {
    "padding_literal": re.compile(r'\.padding\s*\(\s*(?:\.[a-zA-Z]+\s*,\s*)?\d+(?:\.\d+)?\s*\)'),
    "corner_radius_literal": re.compile(r'\.cornerRadius\s*\(\s*\d+(?:\.\d+)?\s*\)'),
    "color_red_literal": re.compile(r'\bColor\s*\(\s*red\s*:'),
    "font_size_literal": re.compile(r'\.font\s*\(\s*\.system\s*\(\s*size\s*:'),
}

findings = []

for base_dir in directories:
    full_path = os.path.join(os.getcwd(), base_dir)
    if not os.path.exists(full_path):
        print(f"Directory not found: {full_path}")
        continue
    for root, dirs, files in os.walk(full_path):
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, os.getcwd())
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                    for idx, line in enumerate(lines, 1):
                        # Simple comment stripping (approximate)
                        stripped_line = line.split('//')[0].strip()
                        for name, pat in patterns.items():
                            match = pat.search(stripped_line)
                            if match:
                                findings.append({
                                    "file": relative_path,
                                    "line": idx,
                                    "pattern": name,
                                    "content": line.strip(),
                                    "match": match.group(0)
                                })
                except Exception as e:
                    print(f"Error reading {file_path}: {e}")

print(f"Total violations found: {len(findings)}")
for idx, f in enumerate(findings, 1):
    print(f"{idx}. {f['file']}:{f['line']} ({f['pattern']}): {f['content']}")
