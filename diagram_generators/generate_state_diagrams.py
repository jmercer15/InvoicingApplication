import os
import re
from collections import defaultdict
import argparse
import xml.etree.ElementTree as ET
import json

def find_swift_files(src_path):
    """Find all .swift files in the source directory."""
    swift_files = []
    for root, _, files in os.walk(src_path):
        for file in files:
            if file.endswith('.swift'):
                swift_files.append(os.path.join(root, file))
    return swift_files

def parse_status_constants(app_constants_path):
    """
    Parses AppConstants.swift to extract all status constants.
    Returns specific statuses per entity and a generic set of statuses.
    """
    specific_statuses = defaultdict(dict)
    generic_statuses = {}
    current_context = None # Can be 'invoice', 'session', 'general'

    try:
        with open(app_constants_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        section_regex = re.compile(r"//\s*(.+?)\s*Status Values")
        constant_regex = re.compile(r"static let (\w+)\s*=\s*\"([^\"]*)\"")

        for line in lines:
            # Strip whitespace from the entire line before processing
            clean_line = line.strip()

            section_match = section_regex.search(clean_line)
            if section_match:
                header = section_match.group(1).lower()
                if 'invoice' in header:
                    current_context = 'invoice'
                elif 'session' in header:
                    current_context = 'session'
                elif 'client' in header or 'payee' in header or 'general' in header:
                    current_context = 'general'
                else:
                    current_context = None

            constant_match = constant_regex.search(clean_line)
            if constant_match and current_context:
                var_name = constant_match.group(1)
                status_value = constant_match.group(2).strip()
                
                if current_context == 'invoice':
                    specific_statuses['InvoiceEntity'][var_name] = status_value
                elif current_context == 'session':
                    specific_statuses['SessionEntity'][var_name] = status_value
                elif current_context == 'general':
                    # Don't add client-specific statuses to the generic pool
                    if 'clientStatus' not in var_name:
                         generic_statuses[var_name] = status_value
                    # But do add them to the client entity specifically
                    if 'client' in var_name.lower():
                        if 'ClientEntity' not in specific_statuses:
                            specific_statuses['ClientEntity'] = {}
                        specific_statuses['ClientEntity'][var_name] = status_value


    except FileNotFoundError:
        print(f"Error: AppConstants.swift not found at {app_constants_path}")
    
    return specific_statuses, generic_statuses

def get_potential_stateful_entities(model_path):
    """Gets all entities from the model, as any could be stateful."""
    entities = []
    try:
        tree = ET.parse(model_path)
        root = tree.getroot()
        for entity in root.findall('entity'):
            entities.append(entity.get('name'))
    except (ET.ParseError, FileNotFoundError):
        pass
    return entities

def analyze_codebase_for_state_logic(swift_files, entities, all_statuses_by_entity):
    """
    Analyzes all Swift files to find which state attributes are actually used
    and which methods modify them. This is the new analysis engine.
    """
    analysis_results = defaultdict(lambda: {"attribute": None, "modifiers": []})
    
    func_sig_regex = re.compile(r"func\s+(?P<func_name>\w+)\s*\((?P<params>.*?)\)\s*(?:throws)?\s*\{")

    for entity_name in entities:
        entity_param_regex = re.compile(r"\b(\w+)\s*:\s*" + re.escape(entity_name))
        
        status_modifiers = []
        is_active_modifiers = []

        for file_path in swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except (IOError, UnicodeDecodeError): continue

            for func_match in func_sig_regex.finditer(content):
                param_match = entity_param_regex.search(func_match.group('params'))
                if not param_match: continue

                func_name = func_match.group('func_name')
                entity_var_name = param_match.group(1).replace('_', '').strip()
                
                # Capture function body reliably
                body_start_index = func_match.end()
                open_braces = 1
                body_end_index = body_start_index
                for i, char in enumerate(content[body_start_index:]):
                    if char == '{': open_braces += 1
                    elif char == '}': open_braces -= 1
                    if open_braces == 0:
                        body_end_index = body_start_index + i
                        break
                func_body = content[body_start_index:body_end_index]

                # Check for '.status' modifications
                possible_statuses = all_statuses_by_entity.get(entity_name, {})
                value_to_const_map = {v: k for k, v in possible_statuses.items()}
                all_status_literals = [re.escape(f'"{v}"') for v in value_to_const_map.keys()] + [re.escape(f'.{c}') for c in value_to_const_map.values()]
                if all_status_literals:
                    assign_regex_str = rf"{re.escape(entity_var_name)}\.status\s*=\s*(?P<val>({'|'.join(all_status_literals)}|(?P<var>\w+)))"
                    for assign_match in re.finditer(assign_regex_str, func_body):
                        if assign_match.group('var') and assign_match.group('var') not in value_to_const_map:
                            status_modifiers.append((func_name, "(Dynamic)"))
                        else:
                            status_val = assign_match.group('val').replace('.', '').strip('"')
                            to_state = possible_statuses.get(status_val, status_val)
                            if to_state: status_modifiers.append((func_name, to_state))

                # Check for '.isActive' modifications
                assign_regex_str = rf"{re.escape(entity_var_name)}\.isActive\s*=\s*(?P<val>true|false|(?P<var>\w+))"
                for assign_match in re.finditer(assign_regex_str, func_body):
                    val_str = assign_match.group('val')
                    if val_str == 'true': is_active_modifiers.append((func_name, "Active"))
                    elif val_str == 'false': is_active_modifiers.append((func_name, "Inactive"))
                    else: is_active_modifiers.append((func_name, "(Dynamic)"))
        
        # Prioritize the attribute that is actually modified in the code
        if status_modifiers:
            analysis_results[entity_name]["attribute"] = "status"
            analysis_results[entity_name]["modifiers"] = sorted(list(set(status_modifiers)))
        elif is_active_modifiers:
            analysis_results[entity_name]["attribute"] = "isActive"
            analysis_results[entity_name]["modifiers"] = sorted(list(set(is_active_modifiers)))

    return analysis_results

def generate_state_overview_diagram(entity_name, attribute, possible_states, modifiers):
    """Generates a Mermaid graph diagram showing states and what methods affect them."""
    if not modifiers: return None

    lines = ["graph TD"]
    lines.append(f"    subgraph \"{entity_name} ({attribute})\"")
    lines.append("        subgraph States")
    sanitized_states = {}
    
    # Add all possible states, even if no method points to them
    all_display_states = set(possible_states)
    for _, state in modifiers:
        if state != '(Dynamic)':
            all_display_states.add(state)
            
    for state in sorted(list(all_display_states)):
        node_id = ''.join(e for e in str(state) if e.isalnum())
        if not node_id: node_id = f"state{hash(state)}"
        sanitized_states[state] = node_id
        lines.append(f"            {node_id}[\"{state}\"]")
    
    if any(m[1] == '(Dynamic)' for m in modifiers):
        lines.append("            DynamicState((Dynamic))")
    lines.append("        end")

    lines.append("        subgraph \"State Modifying Methods\"")
    for method in sorted(list(set(m[0] for m in modifiers))):
        lines.append(f"            {method}")
    lines.append("        end")
    lines.append("    end")
    lines.append("")

    for method, state in modifiers:
        node_id = "DynamicState" if state == '(Dynamic)' else sanitized_states.get(state)
        if node_id:
            lines.append(f"    {method} --> {node_id}")

    return '\n'.join(lines)

def main():
    parser = argparse.ArgumentParser(description='Generate Mermaid state overview diagrams based on code analysis.')
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
    model_path = os.path.join(project_root, config['paths']['model_contents_file'])
    app_constants_path = os.path.join(project_root, config['paths']['app_constants'])
    output_dir_root = os.path.join(project_root, config['paths']['output_root'])
    state_machine_subdir = os.path.join(output_dir_root, config['output_names']['state_machine_subdir'])

    if not os.path.exists(state_machine_subdir):
        os.makedirs(state_machine_subdir)

    swift_files = find_swift_files(src_path)
    specific_statuses, generic_statuses = parse_status_constants(app_constants_path)
    potential_entities = get_potential_stateful_entities(model_path)
    
    all_statuses = defaultdict(dict)
    for entity in potential_entities:
        all_statuses[entity] = specific_statuses.get(entity, generic_statuses)

    print("Analyzing codebase for state logic...")
    analysis_results = analyze_codebase_for_state_logic(swift_files, potential_entities, all_statuses)
    print("Analysis complete.")

    for entity_name, result in analysis_results.items():
        attribute = result["attribute"]
        modifiers = result["modifiers"]
        
        print(f"  - Processing {entity_name} (Attribute: {attribute})")
        
        if not modifiers:
            # This is not an error, just means no state changes were found for this entity
            continue
            
        possible_states = list(all_statuses.get(entity_name, {}).values())
        if attribute == 'isActive':
            possible_states = ["Active", "Inactive"]
        
        diagram_code = generate_state_overview_diagram(entity_name, attribute, possible_states, modifiers)
        
        if not diagram_code:
            print(f"    - Diagram for {entity_name} was empty and not saved.")
            continue
            
        output_content = f"""# State Overview: {entity_name}
This diagram shows the methods that can modify the `{attribute}` of a `{entity_name}` and the potential resulting states.

```mermaid
{diagram_code}
```
"""
        note_path = os.path.join(state_machine_subdir, f"State Overview - {entity_name}.md")
        with open(note_path, 'w', encoding='utf-8') as f:
            f.write(output_content)
        
        print(f"    - Diagram saved to {note_path}")

if __name__ == '__main__':
    main()