import os
import re
from collections import defaultdict
import argparse
from glob import glob
import json

def find_swift_files(src_path):
    """Find all .swift files in the source directory."""
    swift_files = []
    for root, _, files in os.walk(src_path):
        for file in files:
            if file.endswith('.swift'):
                swift_files.append(os.path.join(root, file))
    return swift_files

def parse_definitions(swift_files):
    """Parse swift files to find type definitions (class, struct, enum)."""
    definition_regex = re.compile(r'\b(class|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]+)')
    definitions = {}
    for file_path in swift_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            found_definitions = definition_regex.findall(content)
            if found_definitions:
                for _, name in found_definitions:
                    definitions[name] = file_path
        except Exception as e:
            print(f"Could not read or parse {file_path}: {e}")
    return definitions

def find_dependencies(swift_files, all_definitions):
    """Find dependencies between swift components."""
    dependencies = defaultdict(set)
    all_type_names = set(all_definitions.keys())

    for file_path in swift_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find which types are defined in the current file
            current_file_types = {name for name, path in all_definitions.items() if path == file_path}
            if not current_file_types:
                continue

            # Find all potential dependency words in the file
            words = set(re.findall(r'\b[A-Za-z_][A-Za-z0-9_]+\b', content))
            used_types = words.intersection(all_type_names)

            for source_type in current_file_types:
                for used_type in used_types:
                    if used_type != source_type and used_type in all_definitions and all_definitions[used_type] != file_path:
                        dependencies[source_type].add(used_type)

        except Exception as e:
            print(f"Could not process dependencies for {file_path}: {e}")
    return dependencies

def invert_dependencies(dependencies):
    """Create a map of components to the components that use them."""
    dependents = defaultdict(set)
    for source, deps in dependencies.items():
        for dep in deps:
            dependents[dep].add(source)
    return dependents

def get_component_type(component_name):
    """Determine a component's type from its name for tagging."""
    name_lower = component_name.lower()
    if 'viewmodel' in name_lower:
        return 'viewmodel'
    if 'view' in name_lower:
        return 'view'
    if 'service' in name_lower:
        return 'service'
    if 'manager' in name_lower:
        return 'manager'
    if 'entity' in name_lower:
        return 'entity'
    if 'component' in name_lower:
        return 'component'
    return 'utility'

def generate_local_mermaid_graph(component_name, dependencies, dependents):
    """Generates a small Mermaid graph for a single component and its direct connections."""
    lines = ["graph TD;"]
    
    # Define the central node with special styling
    lines.append(f'    subgraph "Current Component"')
    lines.append(f'        {component_name}(("{component_name}"));')
    lines.append('    end')
    lines.append(f'    style {component_name} fill:#5DADE2,stroke:#1B2631,stroke-width:3px,color:#000')

    # Add dependencies ("Uses")
    if dependencies:
        lines.append('    subgraph "Dependencies (Uses)"')
        for dep in sorted(list(dependencies)):
            lines.append(f'        {dep};')
        lines.append('    end')
        for dep in sorted(list(dependencies)):
            lines.append(f'    {component_name} --> {dep};')

    # Add dependents ("Used By")
    if dependents:
        lines.append('    subgraph "Dependents (Used By)"')
        for dep in sorted(list(dependents)):
            lines.append(f'        {dep};')
        lines.append('    end')
        for dep in sorted(list(dependents)):
            lines.append(f'    {dep} --> {component_name};')
            
    return '\n'.join(lines)

def create_juggl_notes(dependencies, all_definitions, src_path, output_dir):
    """Create a markdown note for each component with its dependencies."""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    dependents = invert_dependencies(dependencies)
    all_components = set(dependencies.keys()) | set(dependents.keys())

    print(f"Generating {len(all_components)} notes for Juggl...")

    for component_name in all_components:
        note_path = os.path.join(output_dir, f"{component_name}.md")
        
        component_file_path = all_definitions.get(component_name, "")
        relative_path = os.path.relpath(component_file_path, os.path.dirname(src_path)) if component_file_path else ""
        component_type = get_component_type(component_name)

        with open(note_path, 'w', encoding='utf-8') as f:
            # YAML Frontmatter for Juggl styling
            f.write("---\n")
            f.write(f"tags: [code_component, {component_type}]\n")
            if relative_path:
                f.write(f"filepath: \"{relative_path}\"\n")
            f.write("---\n\n")

            # Note Content
            f.write(f"# {component_name}\n\n")
            if relative_path:
                f.write(f"**Source:** `{relative_path}`\n\n")

            # Dependencies
            if component_name in dependencies and dependencies[component_name]:
                f.write("## Dependencies (Uses)\n")
                for dep in sorted(list(dependencies[component_name])):
                    f.write(f"- [[{dep}]]\n")
                f.write("\n")

            # Dependents
            if component_name in dependents and dependents[component_name]:
                f.write("## Used By\n")
                for dep in sorted(list(dependents[component_name])):
                    f.write(f"- [[{dep}]]\n")
                f.write("\n")

            # Embedded Mermaid Diagram
            f.write("## Visual Relationship Graph\n\n")
            f.write("```mermaid\n")
            mermaid_code = generate_local_mermaid_graph(
                component_name, 
                dependencies.get(component_name, set()), 
                dependents.get(component_name, set())
            )
            f.write(mermaid_code)
            f.write("\n```\n")

    print("Juggl note generation complete.")

def find_swift_declarations(file_path):
    """
    Parses a Swift file to find all class, struct, enum, and protocol declarations.
    """
    declarations = {}
    declaration_regex = re.compile(
        r"^(?:\s*(?:public|private|internal|open|fileprivate)\s+)?\s*"
        r"(class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"
    )
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                match = declaration_regex.match(line)
                if match:
                    decl_type, name = match.groups()
                    # Use relative path for cleaner output in notes
                    relative_path = os.path.relpath(file_path)
                    declarations[name] = {'type': decl_type, 'file': relative_path, 'file_path': file_path}
    except (IOError, UnicodeDecodeError) as e:
        print(f"Warning: Could not read file {file_path}: {e}")
    return declarations

def analyze_dependencies(files, declarations, exclude_patterns, root_dir):
    """
    Analyzes Swift files to find dependencies between declared components.
    """
    dependencies = defaultdict(list)
    declared_component_names = set(declarations.keys())

    # Create a regex to find any of the declared component names
    # Add word boundaries to avoid matching substrings
    usage_regex = re.compile(r'\b(' + '|'.join(re.escape(name) for name in declared_component_names) + r')\b')

    for file_path in files:
        owner_components = [name for name, data in declarations.items() if data['file_path'] == file_path]
        if not owner_components:
            continue
        
        owner_component = owner_components[0]

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                potential_deps = usage_regex.findall(content)
                
                for dep in set(potential_deps):
                    if dep != owner_component and dep in declared_component_names:
                        dependencies[owner_component].append(dep)

        except (IOError, UnicodeDecodeError):
            continue
            
    for component in dependencies:
        dependencies[component] = sorted(list(set(dependencies[component])))

    return dependencies

def generate_mermaid_diagram(component_name, dependencies, declarations):
    """Generates a small local Mermaid diagram for a single component."""
    lines = ["graph TD"]
    lines.append(f"    {component_name}([{component_name}])")
    
    for dep in dependencies:
        if dep in declarations:
            lines.append(f"    {component_name} --> {dep}")
    
    lines.append(f"    style {component_name} fill:#007AFF,stroke:#333,stroke-width:2px,color:#fff")

    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(
        description="Generate component dependency notes for Juggl with embedded Mermaid diagrams."
    )
    parser.add_argument('--config', required=True, help='Path to the JSON configuration file.')
    args = parser.parse_args()

    # Load config
    try:
        with open(args.config, 'r') as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading config file: {e}")
        return

    # Get paths from config
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(args.config)))
    src_path = os.path.join(project_root, config['paths']['src_code'])
    output_dir_root = os.path.join(project_root, config['paths']['output_root'])
    juggl_output_dir = os.path.join(output_dir_root, config['output_names']['juggl_subdir'])
    exclude_patterns = config['dependency_analysis']['exclude_patterns']

    if not os.path.exists(juggl_output_dir):
        os.makedirs(juggl_output_dir)

    print(f"Scanning for Swift files in {src_path}...")
    swift_files = [y for x in os.walk(src_path) for y in glob(os.path.join(x[0], '*.swift'))]
    print(f"Found {len(swift_files)} Swift files.")

    declarations = {}
    for file in swift_files:
        declarations.update(find_swift_declarations(file))
    
    print(f"Found {len(declarations)} component declarations.")

    print("Analyzing dependencies...")
    dependencies = analyze_dependencies(swift_files, declarations, exclude_patterns, project_root)

    print(f"Generating {len(declarations)} notes for Juggl...")
    for component, data in declarations.items():
        deps = dependencies.get(component, [])
        
        links_content = "\n".join(f"- [[{dep}]]" for dep in deps)
        mermaid_content = generate_mermaid_diagram(component, deps, declarations)

        content = f"""# {component}

- **Type**: `{data['type']}`
- **File**: `[[{data['file']}]]`

## Dependencies

{links_content if links_content else "No dependencies found."}

## Local Dependency Graph
```mermaid
{mermaid_content}
```
"""
        safe_filename = re.sub(r'[\\/*?:"<>|]',"_", component)
        note_path = os.path.join(juggl_output_dir, f"{safe_filename}.md")
        with open(note_path, 'w', encoding='utf-8') as f:
            f.write(content)

    print("Juggl note generation complete.")

if __name__ == '__main__':
    main() 