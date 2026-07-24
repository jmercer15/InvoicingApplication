import re
import subprocess
import os

modified_packages = [
    "Packages/Feature.Invoices",
    "Packages/Feature.BillingHub",
    "Packages/Feature.Calendar",
    "Packages/Feature.Settings",
    "Packages/Feature.InvoiceTemplateEditor",
    "Packages/AppShell"
]

def get_modified_files():
    try:
        output = subprocess.check_output(["git", "diff", "--name-only", "main...HEAD"], text=True)
    except subprocess.CalledProcessError:
        try:
            output = subprocess.check_output(["git", "diff", "--name-only"], text=True)
        except subprocess.CalledProcessError:
            return []
    
    files = [f.strip() for f in output.split('\n') if f.strip().endswith('.swift')]
    return [f for f in files if any(f.startswith(pkg) for pkg in modified_packages)]

def audit_file(filepath):
    errors = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for i, line in enumerate(lines, 1):
        # 1. Raw padding literals: .padding(10) or .padding(.all, 10)
        # Match .padding( followed by optional enum e.g. .horizontal, and then a raw digit/number
        if re.search(r'\.padding\(\s*([0-9]|-[0-9])', line):
            errors.append((i, "Raw numeric padding literal", line.strip()))
        elif re.search(r'\.padding\(\s*\.[a-zA-Z]+\s*,\s*([0-9]|-[0-9])', line):
            errors.append((i, "Raw numeric padding literal with edge", line.strip()))
            
        # 2. Raw cornerRadius literals: .cornerRadius(8)
        if re.search(r'\.cornerRadius\(\s*([0-9])', line):
            errors.append((i, "Raw numeric corner-radius literal", line.strip()))
            
        # 3. Raw Color(red:...) or Color(hex:...) literals
        if re.search(r'Color\s*\(\s*red:', line):
            errors.append((i, "Raw Color(red:...) literal", line.strip()))
        if re.search(r'Color\s*\(\s*hex:', line):
            errors.append((i, "Raw Color(hex:...) literal", line.strip()))
        if re.search(r'Color\s*\(\s*white:', line):
            errors.append((i, "Raw Color(white:...) literal", line.strip()))
            
        # 4. Raw font size literals: .font(.system(size: 14))
        if re.search(r'\.font\(\s*\.system\(\s*size:', line):
            errors.append((i, "Raw font-size literal", line.strip()))
            
    return errors

def main():
    files = get_modified_files()
    print(f"Auditing {len(files)} modified Swift files...")
    
    all_errors = {}
    for f in files:
        if not os.path.exists(f):
            continue
        errors = audit_file(f)
        if errors:
            all_errors[f] = errors
            
    if all_errors:
        print("\n❌ INTEGRITY VIOLATION / ISSUES FOUND:")
        for filepath, errors in all_errors.items():
            print(f"\nFile: {filepath}")
            for line_no, err_type, line_content in errors:
                print(f"  Line {line_no}: [{err_type}] -> {line_content}")
    else:
        print("\n✅ CLEAN! No design token violations found in modified files.")

if __name__ == '__main__':
    main()
