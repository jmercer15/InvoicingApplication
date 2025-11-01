#!/usr/bin/env python3
"""
Swift Entity Parser and ER Diagram Generator

This script parses Swift entity files and generates an Entity Relationship diagram
showing all entities, their properties, and relationships.
"""

import re
import os
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass
from pathlib import Path

@dataclass
class Property:
    name: str
    type: str
    is_optional: bool = False
    is_relationship: bool = False
    delete_rule: str = None
    inverse: str = None
    is_unique: bool = False

@dataclass
class Entity:
    name: str
    properties: List[Property]
    relationships: List[Property]

class SwiftEntityParser:
    def __init__(self):
        self.entities: Dict[str, Entity] = {}
        
    def parse_file(self, file_path: str) -> Entity:
        """Parse a Swift entity file and extract entity information."""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract entity name
        entity_match = re.search(r'@Model\s+public\s+class\s+(\w+)', content)
        if not entity_match:
            raise ValueError(f"Could not find @Model class in {file_path}")
        
        entity_name = entity_match.group(1)
        
        # Extract properties and relationships
        properties = []
        relationships = []
        
        # Find all property declarations
        property_pattern = r'(@Attribute\([^)]*\)\s+)?(@Relationship\([^)]*\)\s+)?(var|let)\s+(\w+):\s*([^=\n/]+)(?:\s*=\s*[^=\n]+)?(?://.*)?'
        
        for match in re.finditer(property_pattern, content, re.MULTILINE):
            attribute_line = match.group(1) or ""
            relationship_line = match.group(2) or ""
            var_let = match.group(3)
            prop_name = match.group(4)
            prop_type = match.group(5).strip()
            
            # Skip if it's a computed property, method, or contains problematic characters
            if ('{' in prop_type or 
                'func' in content[content.find(match.group(0)):content.find(match.group(0)) + 200] or
                '[' in prop_type or
                ']' in prop_type or
                prop_name.startswith('_') or
                prop_name in ['displayName', 'icon', 'color', 'components', 'streetComponents', 
                             'formattedAddress', 'validationStatusEnum', 'isValidForGeocoding', 
                             'hasValidCoordinates', 'itemsArray', 'subtotal', 'discountAmount', 
                             'taxAmount', 'calculatedTotal', 'formattedInvoiceNumber', 'formattedTotal', 
                             'isValid', 'isOverdue', 'daysUntilDue', 'lineTotal', 'lineTaxAmount', 
                             'lineTotalWithTax', 'formattedLineTotal', 'formattedRate', 'formattedQuantity', 
                             'isNDISItem', 'ndisClaimTypeDisplay', 'totalRateModifiers', 'rateModifiersSummary', 
                             'modifiers', 'regionalPrices', 'auditLogs']):
                continue
            
            # Check if it's a relationship
            is_relationship = bool(relationship_line)
            
            # Determine if it's optional
            is_optional = prop_type.endswith('?')
            if is_optional:
                prop_type = prop_type[:-1].strip()
            
            # Clean up the type for relationships
            if is_relationship:
                # Remove array brackets and clean up the type
                prop_type = prop_type.replace('[', '').replace(']', '').strip()
            delete_rule = None
            inverse = None
            
            if is_relationship:
                # Extract delete rule
                delete_rule_match = re.search(r'deleteRule:\s*\.(\w+)', relationship_line)
                if delete_rule_match:
                    delete_rule = delete_rule_match.group(1)
                
                # Extract inverse relationship
                inverse_match = re.search(r'inverse:\s*\\(\w+Entity\.\w+)', relationship_line)
                if inverse_match:
                    inverse = inverse_match.group(1)
            
            # Check if it's unique
            is_unique = bool(attribute_line and 'unique' in attribute_line)
            
            prop = Property(
                name=prop_name,
                type=prop_type,
                is_optional=is_optional,
                is_relationship=is_relationship,
                delete_rule=delete_rule,
                inverse=inverse,
                is_unique=is_unique
            )
            
            if is_relationship:
                relationships.append(prop)
            else:
                properties.append(prop)
        
        entity = Entity(name=entity_name, properties=properties, relationships=relationships)
        self.entities[entity_name] = entity
        return entity
    
    def generate_mermaid_er_diagram(self) -> str:
        """Generate a Mermaid ER diagram from parsed entities."""
        mermaid_lines = ["erDiagram"]
        
        # Add entities with their properties
        for entity_name, entity in self.entities.items():
            mermaid_lines.append(f"    {entity_name} {{")
            
            # Add properties
            for prop in entity.properties:
                prop_type = self._format_type_for_mermaid(prop.type)
                # Don't include ? in Mermaid ER diagrams as it causes syntax errors
                unique_marker = " PK" if prop.is_unique else ""
                mermaid_lines.append(f"        {prop_type} {prop.name}{unique_marker}")
            
            # Add relationship properties (as foreign keys)
            for rel in entity.relationships:
                if rel.inverse:
                    # Extract the target entity from inverse relationship
                    target_entity = rel.inverse.split('.')[0]
                    fk_name = f"{target_entity.lower()}Id"
                    mermaid_lines.append(f"        UUID {fk_name}")
            
            mermaid_lines.append("    }")
            mermaid_lines.append("")  # Empty line for readability
        
        # Add relationships
        for entity_name, entity in self.entities.items():
            for rel in entity.relationships:
                if rel.inverse:
                    target_entity = rel.inverse.split('.')[0]
                else:
                    # For relationships without inverse, try to determine target entity from type
                    target_entity = rel.type.replace('?', '').strip()
                
                # Use proper Mermaid ER diagram relationship syntax
                mermaid_lines.append(f"    {entity_name} ||--o| {target_entity} : \"{rel.name}\"")
        
        return "\n".join(mermaid_lines)
    
    def _format_type_for_mermaid(self, swift_type: str) -> str:
        """Convert Swift types to more readable format for Mermaid."""
        type_mapping = {
            'String': 'string',
            'Int': 'int',
            'Int32': 'int',
            'Int16': 'int',
            'Double': 'float',
            'Bool': 'boolean',
            'Date': 'datetime',
            'UUID': 'UUID',
            'Data': 'blob'
        }
        
        # Clean up the type string
        swift_type = swift_type.strip()
        
        # Handle array types - extract the base type
        if '[' in swift_type and ']' in swift_type:
            # Extract type from [Type] format
            base_type = swift_type.split('[')[1].split(']')[0].strip()
            return f"array<{type_mapping.get(base_type, base_type)}>"
        
        # Handle optional types (already stripped)
        return type_mapping.get(swift_type, swift_type)
    
    def _get_relationship_type(self, rel: Property) -> str:
        """Determine the relationship cardinality for Mermaid."""
        # For Mermaid ER diagrams, we need to determine cardinality based on the relationship
        # Most relationships in SwiftData are one-to-many or many-to-one
        return "o"  # One-to-many (most common in this data model)
    
    def generate_detailed_report(self) -> str:
        """Generate a detailed text report of all entities and relationships."""
        report_lines = ["# Entity Relationship Report\n"]
        
        for entity_name, entity in sorted(self.entities.items()):
            report_lines.append(f"## {entity_name}")
            report_lines.append("")
            
            # Properties
            if entity.properties:
                report_lines.append("### Properties:")
                for prop in entity.properties:
                    optional_str = " (optional)" if prop.is_optional else ""
                    unique_str = " (unique)" if prop.is_unique else ""
                    report_lines.append(f"- `{prop.name}`: {prop.type}{optional_str}{unique_str}")
                report_lines.append("")
            
            # Relationships
            if entity.relationships:
                report_lines.append("### Relationships:")
                for rel in entity.relationships:
                    delete_rule_str = f" (delete: {rel.delete_rule})" if rel.delete_rule else ""
                    inverse_str = f" -> {rel.inverse}" if rel.inverse else ""
                    report_lines.append(f"- `{rel.name}`: {rel.type}{delete_rule_str}{inverse_str}")
                report_lines.append("")
        
        return "\n".join(report_lines)

def main():
    """Main function to parse entities and generate diagrams."""
    parser = SwiftEntityParser()
    
    # Define the entity files to parse
    entity_files = [
        "InvoicingApplication/Models/Entities/AddressEntity.swift",
        "InvoicingApplication/Models/Entities/BusinessEntity.swift",
        "InvoicingApplication/Models/Entities/ClientEntity.swift",
        "InvoicingApplication/Models/Entities/ClientServiceEntity.swift",
        "InvoicingApplication/Models/Entities/CreditHistoryEntryEntity.swift",
        "InvoicingApplication/Models/Entities/EventEntity.swift",
        "InvoicingApplication/Models/Entities/InvoiceEntity.swift",
        "InvoicingApplication/Models/Entities/InvoiceItemEntity.swift",
        "InvoicingApplication/Models/Entities/NDISItemEntity.swift",
        "InvoicingApplication/Models/Entities/PayeeEntity.swift",
        "InvoicingApplication/Models/Entities/PlanManagerEntity.swift",
        "InvoicingApplication/Models/Entities/RegionalPriceEntity.swift",
        "InvoicingApplication/Models/Entities/TravelChargeEntity.swift",
        "InvoicingApplication/Models/Entities/SessionEntity.swift"
    ]
    
    print("Parsing Swift entity files...")
    
    # Parse all entity files
    for file_path in entity_files:
        if os.path.exists(file_path):
            try:
                entity = parser.parse_file(file_path)
                print(f"✓ Parsed {entity.name} from {file_path}")
            except Exception as e:
                print(f"✗ Error parsing {file_path}: {e}")
        else:
            print(f"✗ File not found: {file_path}")
    
    print(f"\nParsed {len(parser.entities)} entities successfully.")
    
    # Generate Mermaid ER diagram
    print("\nGenerating Mermaid ER diagram...")
    mermaid_diagram = parser.generate_mermaid_er_diagram()
    
    # Save Mermaid diagram
    with open("entity_relationship_diagram.mmd", "w", encoding="utf-8") as f:
        f.write(mermaid_diagram)
    print("✓ Saved Mermaid diagram to entity_relationship_diagram.mmd")
    
    # Generate detailed report
    print("Generating detailed report...")
    detailed_report = parser.generate_detailed_report()
    
    # Save detailed report
    with open("entity_relationship_report.md", "w", encoding="utf-8") as f:
        f.write(detailed_report)
    print("✓ Saved detailed report to entity_relationship_report.md")
    
    # Print summary
    print("\n" + "="*50)
    print("SUMMARY")
    print("="*50)
    print(f"Total entities parsed: {len(parser.entities)}")
    print("Entities:")
    for entity_name in sorted(parser.entities.keys()):
        entity = parser.entities[entity_name]
        print(f"  - {entity_name}: {len(entity.properties)} properties, {len(entity.relationships)} relationships")
    
    print(f"\nFiles generated:")
    print(f"  - entity_relationship_diagram.mmd (Mermaid ER diagram)")
    print(f"  - entity_relationship_report.md (Detailed report)")
    
    print(f"\nTo view the Mermaid diagram:")
    print(f"  1. Copy the contents of entity_relationship_diagram.mmd")
    print(f"  2. Paste into Mermaid Live Editor: https://mermaid.live/")
    print(f"  3. Or use any Mermaid-compatible viewer")

if __name__ == "__main__":
    main()
