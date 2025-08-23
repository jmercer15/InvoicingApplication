#!/bin/bash

# --- Path Setup ---
# This script assumes it is being run from the project's root directory.
# PROJECT_ROOT is the current directory.
PROJECT_ROOT="$(pwd)"

# The generators and config are in a subdirectory.
DIAGRAM_GENERATORS_DIR="$PROJECT_ROOT/diagram_generators"
CONFIG_FILE="$DIAGRAM_GENERATORS_DIR/config.json"

# --- Pre-flight Checks ---
echo "--- Running Pre-flight Diagnostics ---"
echo "Project Root: $PROJECT_ROOT"
echo "Diagram Generators Directory: $DIAGRAM_GENERATORS_DIR"
echo "Config File: $CONFIG_FILE"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed. Please install it to continue."
    echo "On macOS, you can use Homebrew: brew install jq"
    exit 1
fi

# Check for lizard
if ! command -v lizard &> /dev/null; then
    echo "⚠️  Warning: lizard is not installed. Code complexity analysis will be skipped."
    echo "To enable this feature, run: pip install lizard"
    LIZARD_INSTALLED=false
else
    LIZARD_INSTALLED=true
fi

# Check for config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi
echo "✅ Configuration checks passed."

# --- Read Paths from Config ---
# Paths in config are relative to the project root.
OUTPUT_ROOT_REL=$(jq -r '.paths.output_root' "$CONFIG_FILE")
OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_ROOT_REL"

JUGGL_SUBDIR=$(jq -r '.output_names.juggl_subdir' "$CONFIG_FILE")
STATE_SUBDIR=$(jq -r '.output_names.state_machine_subdir' "$CONFIG_FILE")
DEP_SUBDIR=$(jq -r '.output_names.dependency_graph_subdir' "$CONFIG_FILE")
ER_FILENAME=$(jq -r '.output_names.er_diagram_filename' "$CONFIG_FILE")
INDEX_FILENAME=$(jq -r '.output_names.index_filename' "$CONFIG_FILE")
COMPLEXITY_FILENAME=$(jq -r '.complexity_analysis.report_filename' "$CONFIG_FILE")

echo "Output directory set to: $OUTPUT_DIR"

# --- Clean Previous Output ---
echo -e "\n--- Cleaning previous output ---"
# Remove subdirectories of generated files
rm -rf "$OUTPUT_DIR/$JUGGL_SUBDIR"
rm -rf "$OUTPUT_DIR/$STATE_SUBDIR"
rm -rf "$OUTPUT_DIR/$DEP_SUBDIR"
# Remove top-level generated files
rm -f "$OUTPUT_DIR/$ER_FILENAME"
rm -f "$OUTPUT_DIR/$INDEX_FILENAME"
rm -f "$OUTPUT_DIR/$COMPLEXITY_FILENAME"
echo "Previous output cleaned."

# --- Setup Output Directories ---
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$JUGGL_SUBDIR"
mkdir -p "$OUTPUT_DIR/$STATE_SUBDIR"
mkdir -p "$OUTPUT_DIR/$DEP_SUBDIR"

# --- Run Generators ---
echo -e "\n--- Running Juggl Note Generator ---"
python3 "$DIAGRAM_GENERATORS_DIR/generate_juggl_notes.py" --config "$CONFIG_FILE"
echo "--- Finished Juggl Notes ---"

echo -e "\n--- Running State Machine Diagram Generator ---"
python3 "$DIAGRAM_GENERATORS_DIR/generate_state_diagrams.py" --config "$CONFIG_FILE"
echo "--- Finished State Machine Diagrams ---"

echo -e "\n--- Running Core Data ER Diagram Generator ---"
python3 "$DIAGRAM_GENERATORS_DIR/generate_er_diagram.py" --config "$CONFIG_FILE"
echo "--- Finished Core Data ER Diagram ---"

echo -e "\n--- Running Dependency Graph Generator ---"
python3 "$DIAGRAM_GENERATORS_DIR/generate_dependency_graph.py" --config "$CONFIG_FILE"
echo "--- Finished Dependency Graphs ---"

# --- Run Code Complexity Analyzer ---
if [ "$LIZARD_INSTALLED" = true ]; then
    echo -e "\n--- Running Code Complexity Analyzer ---"
    python3 "$DIAGRAM_GENERATORS_DIR/generate_complexity_report.py" --config "$CONFIG_FILE"
    echo "--- Finished Code Complexity Analysis ---"
else
    echo -e "\n--- Skipping Code Complexity Analysis (lizard not installed) ---"
fi

# --- Generate Dashboard Index File ---
echo -e "\n--- Generating Dashboard File ---"
INDEX_FILE_PATH="$OUTPUT_DIR/$INDEX_FILENAME"

# Create a function to generate markdown links for files in a directory
generate_links() {
    local dir="$1"
    local subdir_name="$2"
    
    if [ ! -d "$dir" ]; then return; fi
    
    local files=("$dir"/*.md)
    if [ ${#files[@]} -gt 0 ] && [ -e "${files[0]}" ]; then
        echo -e "\n### $subdir_name\n" >> "$INDEX_FILE_PATH"
        for file in "${files[@]}"; do
            filename=$(basename "$file")
            # Correcting link path for Obsidian
            link_path="${subdir_name}/${filename}"
            # URL encode spaces
            link_path_encoded=$(echo "$link_path" | sed 's/ /%20/g')
            echo "- [[$link_path_encoded|${filename%.md}]]" >> "$INDEX_FILE_PATH"
        done
    fi
}

# Start writing the index file
echo "# Codebase Visualization Dashboard" > "$INDEX_FILE_PATH"
echo "This dashboard provides quick access to all automatically generated diagrams and visualizations." >> "$INDEX_FILE_PATH"

# Add link to ER Diagram
if [ -f "$OUTPUT_DIR/$ER_FILENAME" ]; then
    echo -e "\n## Entity-Relationship Diagram\n" >> "$INDEX_FILE_PATH"
    # URL encode spaces
    er_filename_encoded=$(echo "$ER_FILENAME" | sed 's/ /%20/g')
    echo "- [[$er_filename_encoded|View Core Data ER Diagram]]" >> "$INDEX_FILE_PATH"
fi

# Add link to Complexity Report
if [ -f "$OUTPUT_DIR/$COMPLEXITY_FILENAME" ]; then
    echo -e "\n## Code Quality Reports\n" >> "$INDEX_FILE_PATH"
    # URL encode spaces
    complexity_filename_encoded=$(echo "$COMPLEXITY_FILENAME" | sed 's/ /%20/g')
    echo "- [[$complexity_filename_encoded|View Code Complexity Report]]" >> "$INDEX_FILE_PATH"
fi

# Add links to State Machines, Dependency Graphs, and Juggl notes
echo -e "\n## Detailed Views" >> "$INDEX_FILE_PATH"
generate_links "$OUTPUT_DIR/$STATE_SUBDIR" "$STATE_SUBDIR"
generate_links "$OUTPUT_DIR/$DEP_SUBDIR" "$DEP_SUBDIR"
generate_links "$OUTPUT_DIR/$JUGGL_SUBDIR" "$JUGGL_SUBDIR"

echo "Dashboard generated at $INDEX_FILE_PATH"
echo "--- Finished Dashboard ---"

echo -e "\n🎉 All diagrams generated successfully!" 