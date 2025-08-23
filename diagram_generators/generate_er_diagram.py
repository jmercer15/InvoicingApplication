import xml.etree.ElementTree as ET
import argparse
from collections import defaultdict
import os
import re
import json

def find_core_data_model(search_path):
    """Recursively search for the Core Data model contents file."""
    for root, dirs, files in os.walk(search_path):
        if root.endswith(".xcdatamodel") and "contents" in files:
            return os.path.join(root, "contents")
    return None

def parse_xcdatamodel(root):
    """
    Parses the XML root of a Core Data model to extract entities, attributes, and relationships.
    """
    entities = defaultdict(lambda: {'attributes': [], 'relationships': []})
    
    # The 'root' is already the parsed XML element. No need to parse a file.
    for entity in root.findall('entity'):
        name = entity.get('name')
        entities[name]['attributes'] = [
            (attr.get('name'), attr.get('attributeType'))
            for attr in entity.findall('attribute')
        ]
        entities[name]['relationships'] = [
            {
                'name': rel.get('name'),
                'destinationEntity': rel.get('destinationEntity'),
                'toMany': rel.get('toMany') == 'YES',
                'inverseName': rel.get('inverseName'),
                'inverseEntity': rel.get('inverseEntity')
            }
            for rel in entity.findall('relationship')
        ]
    return entities

def generate_mermaid_er_diagram(entities):
    """Generate Mermaid ER diagram syntax."""
    mermaid_string = ["erDiagram"]
    
    # Define entities and their attributes
    for name, data in entities.items():
        mermaid_string.append(f'    {name} {{')
        for attr in data['attributes']:
            # Mermaid ER diagrams require a data type, provide a fallback
            attr_type = attr[1] if attr[1] else 'Unknown'
            mermaid_string.append(f'        {attr_type.replace(" ", "")} {attr[0]}')
        mermaid_string.append('    }')
    
    mermaid_string.append('')
    
    # Define relationships
    processed_rels = set()
    for source_name, data in entities.items():
        for rel in data['relationships']:
            dest_name = rel['destinationEntity']
            
            # Avoid duplicating relationships by sorting names
            rel_key = tuple(sorted((source_name, dest_name)))
            if rel_key in processed_rels:
                continue
            
            # Determine relationship cardinality
            # This is a simplification. For full accuracy, we'd need to check the inverse relationship too.
            # Here we assume the inverse relationship has a similar cardinality structure.
            arrow_left = '|o' if rel['toMany'] else '||'
            arrow_right = 'o|' if entities[dest_name]['relationships'] and any(r['destinationEntity'] == source_name and r['toMany'] for r in entities[dest_name]['relationships']) else '||'
            
            # A more robust check might be needed if inverse relationships aren't consistently defined
            # For now, let's represent based on the 'to_many' flag
            if rel['toMany']:
                # One-to-many or many-to-many
                # Simple assumption: check if inverse is also to_many
                is_inverse_to_many = False
                if dest_name in entities and 'relationships' in entities[dest_name]:
                    for inverse_rel in entities[dest_name]['relationships']:
                        if inverse_rel['destinationEntity'] == source_name and inverse_rel['toMany']:
                            is_inverse_to_many = True
                            break
                
                if is_inverse_to_many:
                     mermaid_string.append(f'    {source_name} o{{--}}o {dest_name} : "{rel["name"]}"')
                else:
                     mermaid_string.append(f'    {source_name} ||--o{{ {dest_name} : "{rel["name"]}"')
            else:
                # One-to-one
                mermaid_string.append(f'    {source_name} ||--|| {dest_name} : "{rel["name"]}"')
                
            processed_rels.add(rel_key)

    return '\n'.join(mermaid_string)

def find_and_parse_model(model_path):
    if not os.path.exists(model_path):
        print(f"Error: Core Data model contents file not found at {model_path}")
        return None
    
    try:
        tree = ET.parse(model_path)
        return tree.getroot()
    except ET.ParseError as e:
        print(f"Error parsing model file: {e}")
        return None

def generate_mermaid_code(root):
    entities = parse_xcdatamodel(root)
    return generate_mermaid_er_diagram(entities)

def main():
    parser = argparse.ArgumentParser(description='Generate a Mermaid ER diagram from a CoreData model.')
    parser.add_argument('--config', required=True, help='Path to the JSON configuration file.')
    args = parser.parse_args()

    # Load config
    try:
        with open(args.config, 'r') as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading config file: {e}")
        return

    # Get paths from config, assuming script is run from project root
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(args.config))) # Assumes config is in diagram_generators
    model_path = os.path.join(project_root, config['paths']['model_contents_file'])
    output_dir = os.path.join(project_root, config['paths']['output_root'])
    output_filename = config['output_names']['er_diagram_filename']
    output_path = os.path.join(output_dir, output_filename)
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print(f"Searching for Core Data model at: {model_path}")
    root = find_and_parse_model(model_path)

    if root:
        print("Parsing Core Data model...")
        mermaid_code = generate_mermaid_code(root)
        
        output_content = f"""# Core Data Entity Relationship Diagram

```mermaid
{mermaid_code}
```
"""
        print("Generating Mermaid ER diagram...")
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(output_content)
        print(f"Successfully generated ER diagram at: {output_path}")

if __name__ == '__main__':
    main() 