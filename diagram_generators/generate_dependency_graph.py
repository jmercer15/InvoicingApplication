import os
import re
from collections import defaultdict
import argparse
from glob import glob
import json
import fnmatch

def find_swift_files(src_path, exclude_paths=None):
    """Find all .swift files in the source directory, ignoring excluded paths."""
    if exclude_paths is None:
        exclude_paths = []
    
    # Create absolute paths for reliable matching
    absolute_exclude_paths = [os.path.abspath(os.path.join(src_path, p)) for p in exclude_paths]

    swift_files = []
    for root, _, files in os.walk(src_path):
        absolute_root = os.path.abspath(root)
        
        # Check if the current directory or any of its parents are in the exclude list
        if any(absolute_root.startswith(excluded_path) for excluded_path in absolute_exclude_paths):
            continue
            
        for file in files:
            if file.endswith('.swift'):
                swift_files.append(os.path.join(root, file))
    return swift_files

def parse_definitions(swift_files):
    """Parse swift files to find type definitions (class, struct, enum)."""
    # Regex to find struct, class, or enum definitions and capture their names
    definition_regex = re.compile(r'\b(class|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]+)')
    definitions = {}
    file_definitions = defaultdict(list)

    for file_path in swift_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            found_definitions = definition_regex.findall(content)
            if found_definitions:
                for _, name in found_definitions:
                    # Store mapping from type name to its defining file
                    definitions[name] = file_path
                    # Store all types defined in this file
                    file_definitions[file_path].append(name)
        except Exception as e:
            print(f"Could not read or parse {file_path}: {e}")
            
    return definitions, file_definitions

def find_dependencies(swift_files, all_definitions, file_definitions):
    """Find dependencies between swift files."""
    dependencies = defaultdict(set)
    
    # Create a set of all defined type names for quick lookups
    all_type_names = set(all_definitions.keys())

    for file_path in swift_files:
        current_file_types = file_definitions.get(file_path, [])
        if not current_file_types:
            continue

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Find all potential dependency words in the file
            words = set(re.findall(r'\b[A-Za-z_][A-Za-z0-9_]+\b', content))
            
            # Check which of these words are defined types from our list
            used_types = words.intersection(all_type_names)

            for used_type in used_types:
                # Get the file where the used_type is defined
                definition_file = all_definitions[used_type]
                
                # A dependency exists if the used type is defined in another file
                if definition_file != file_path:
                    # The dependency is from all types in the current file to the used type
                    for source_type in current_file_types:
                        dependencies[source_type].add(used_type)

        except Exception as e:
            print(f"Could not process dependencies for {file_path}: {e}")

    return dependencies

def get_types_in_path(target_path, file_definitions):
    """Get all types defined within a specific directory path."""
    start_nodes = set()
    abs_target_path = os.path.abspath(target_path)
    for file_path, types in file_definitions.items():
        if os.path.abspath(file_path).startswith(abs_target_path):
            start_nodes.update(types)
    return start_nodes

def trace_dependencies(start_nodes, all_dependencies):
    """Trace all dependencies for a given set of starting nodes."""
    traced_deps = defaultdict(set)
    nodes_to_visit = list(start_nodes)
    visited_nodes = set()

    while nodes_to_visit:
        node = nodes_to_visit.pop(0)
        if node in visited_nodes:
            continue
        visited_nodes.add(node)
        
        if node in all_dependencies:
            # Add its dependencies to the graph and the visit queue
            node_deps = all_dependencies[node]
            traced_deps[node].update(node_deps)
            for dep in node_deps:
                if dep not in visited_nodes:
                    nodes_to_visit.append(dep)
    
    return traced_deps

def generate_mermaid_graph(dependencies, all_definitions, src_path):
    """Generate Mermaid graph syntax from dependencies."""
    mermaid_string = ["graph TD;"]
    
    # Group nodes by their directory for subgraphs
    subgraphs = defaultdict(list)
    processed_types = set()

    all_involved_types = set(dependencies.keys()) | set.union(*dependencies.values())

    for type_name in all_involved_types:
        if type_name in all_definitions:
            file_path = all_definitions[type_name]
            # Create a readable subgraph name from the directory path
            relative_path = os.path.relpath(os.path.dirname(file_path), src_path)
            subgraph_name = relative_path.replace('/', ' - ')
            subgraphs[subgraph_name].append(type_name)

    # Add subgraphs to mermaid string
    for subgraph_name, types in subgraphs.items():
        mermaid_string.append(f'    subgraph "{subgraph_name}"')
        for type_name in types:
            mermaid_string.append(f'        {type_name};')
        mermaid_string.append('    end')

    # Add dependencies (edges)
    mermaid_string.append('')
    for source, deps in dependencies.items():
        for dep in deps:
            mermaid_string.append(f'    {source} --> {dep};')
            
    # Add some basic styling
    mermaid_string.append('')
    mermaid_string.append('    %% Styling')
    mermaid_string.append('    classDef feature fill:#2E4053,stroke:#5DADE2,stroke-width:2px,color:#fff;')
    mermaid_string.append('    classDef component fill:#154360,stroke:#5DADE2,stroke-width:2px,color:#fff;')
    mermaid_string.append('    classDef utility fill:#1B2631,stroke:#5DADE2,stroke-width:2px,color:#fff;')
    
    # Apply styles based on path
    for subgraph_name, types in subgraphs.items():
        style_class = "utility" # default
        if "Features" in subgraph_name:
            style_class = "feature"
        elif "Components" in subgraph_name:
            style_class = "component"
        
        for type_name in types:
             mermaid_string.append(f'    class {type_name} {style_class};')

    return '\n'.join(mermaid_string)

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
                    declarations[name] = {'type': decl_type, 'file_path': file_path}
    except (IOError, UnicodeDecodeError) as e:
        print(f"Warning: Could not read file {file_path}: {e}")
    return declarations

def analyze_dependencies(files, declarations, exclude_patterns, root_for_patterns):
    """
    Analyzes Swift files to find dependencies between declared components.
    """
    dependencies = defaultdict(list)
    declared_component_names = set(declarations.keys())
    usage_regex = re.compile(r'\b(' + '|'.join(re.escape(name) for name in declared_component_names) + r')\b')

    for file_path in files:
        # Skip excluded files by matching patterns against the correct base path
        if any(fnmatch.fnmatch(file_path, os.path.join(root_for_patterns, pat)) for pat in exclude_patterns):
            continue

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

def generate_mermaid_diagram(title, declarations, dependencies, scope_declarations):
    """
    Generates a Mermaid diagram for a specific scope of declarations.
    """
    mermaid_lines = ['graph TD']
    
    # relevant dependencies are those where the source is in our scope
    relevant_deps = {k: v for k, v in dependencies.items() if k in scope_declarations}
    
    # all components involved are the sources and all of their destinations
    all_involved_components = set(relevant_deps.keys())
    for deps in relevant_deps.values():
        all_involved_components.update(deps)
        
    # Define subgraphs based on file paths
    subgraphs = defaultdict(list)
    for comp in all_involved_components:
        if comp in declarations:
            file_path = declarations[comp]['file_path']
            dir_name = os.path.basename(os.path.dirname(file_path))
            subgraphs[dir_name].append(comp)

    for dir_name, components in subgraphs.items():
        # Fix: Prepend "dir: " to avoid name collisions between subgraphs and nodes.
        safe_dir_name = f"dir: {dir_name}"
        mermaid_lines.append(f'    subgraph "{safe_dir_name}"')
        for comp in components:
            mermaid_lines.append(f'        {comp}[{comp}]')
        mermaid_lines.append('    end')

    # Add edges
    for source, deps in relevant_deps.items():
        for dest in deps:
            if dest in all_involved_components:
                mermaid_lines.append(f'    {source} --> {dest}')
                
    return '\n'.join(mermaid_lines)

def main():
    parser = argparse.ArgumentParser(description="Generate Mermaid dependency graphs from a Swift codebase.")
    parser.add_argument('--config', required=True, help='Path to the JSON configuration file.')
    args = parser.parse_args()

    # Load config
    try:
        with open(args.config, 'r') as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading config file: {e}")
        return

    # Get paths and settings from config
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(args.config)))
    src_path = os.path.join(project_root, config['paths']['src_code'])
    output_dir_root = os.path.join(project_root, config['paths']['output_root'])
    dep_graph_subdir = os.path.join(output_dir_root, config['output_names']['dependency_graph_subdir'])
    
    feature_subdirs = config['dependency_analysis']['feature_subdirs']
    exclude_patterns = config['dependency_analysis']['exclude_patterns']

    if not os.path.exists(dep_graph_subdir):
        os.makedirs(dep_graph_subdir)
    
    print("Scanning for all Swift files...")
    all_swift_files = [y for x in os.walk(src_path) for y in glob(os.path.join(x[0], '*.swift'))]
    
    print("Finding all declarations...")
    all_declarations = {}
    for file in all_swift_files:
        all_declarations.update(find_swift_declarations(file))
        
    print("Analyzing all dependencies...")
    all_dependencies = analyze_dependencies(all_swift_files, all_declarations, exclude_patterns, src_path)
    
    # Generate a diagram for each feature directory
    for feature_path in feature_subdirs:
        feature_name = os.path.basename(feature_path)
        full_feature_path = os.path.join(src_path, feature_path)
        
        print(f"\n--- Generating diagram for {feature_name} ---")
        
        feature_files = [y for x in os.walk(full_feature_path) for y in glob(os.path.join(x[0], '*.swift'))]
        
        scope_declarations = set()
        for file in feature_files:
            scope_declarations.update(d for d, data in all_declarations.items() if data['file_path'] == file)
            
        if not scope_declarations:
            print(f"No declarations found in {feature_name}, skipping.")
            continue

        mermaid_code = generate_mermaid_diagram(
            f"{feature_name} Dependencies",
            all_declarations,
            all_dependencies,
            scope_declarations
        )
        
        output_file = os.path.join(dep_graph_subdir, f"dependencies_{feature_name}.md")
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"# {feature_name} Dependency Graph\n\n```mermaid\n{mermaid_code}\n```")
            
        print(f"Generated diagram for {feature_name} at {output_file}")

if __name__ == '__main__':
    main() 