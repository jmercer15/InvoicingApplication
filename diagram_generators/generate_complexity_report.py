import argparse
import csv
import io
import json
import os
import subprocess

def run_lizard(src_path):
    """
    Runs the lizard command on the source path and returns the CSV output.
    """
    try:
        command = [
            'lizard',
            '--csv',
            '-l', 'swift',
            src_path
        ]
        print(f"Running command: {' '.join(command)}")
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout
    except FileNotFoundError:
        print("Error: 'lizard' command not found. Please install it with 'pip install lizard'.")
        return None
    except subprocess.CalledProcessError as e:
        print(f"Error running lizard: {e}")
        print(f"Stderr: {e.stderr}")
        return None

def parse_lizard_output(csv_data):
    """
    Parses the CSV output from lizard into a list of dictionaries.
    """
    if not csv_data:
        return []
    
    # Lizard's CSV output might have a summary line at the end that isn't part of the CSV
    lines = csv_data.strip().split('\n')
    csv_content = '\n'.join(line for line in lines if line.count(',') >= 5) # Simple filter for CSV lines

    reader = csv.DictReader(io.StringIO(csv_content))
    # Field names are 'nloc', 'ccn', 'token_count', 'parameter_count', 'location', 'function_name', 'long_function_name', 'filename'
    metrics = []
    for row in reader:
        # Clean up and convert to integers
        try:
            metrics.append({
                'nloc': int(row['nloc']),
                'ccn': int(row['ccn']),
                'params': int(row['parameter_count']),
                'name': row['long_function_name'],
                'file': row['filename']
            })
        except (ValueError, KeyError):
            continue # Skip rows that don't parse correctly
    return metrics

def generate_markdown_table(headers, rows):
    """
    Generates a markdown table from a list of headers and a list of rows.
    """
    header_line = "| " + " | ".join(headers) + " |"
    separator_line = "| " + " | ".join(['---'] * len(headers)) + " |"
    body_lines = [f"| {' | '.join(map(str, row))} |" for row in rows]
    return "\n".join([header_line, separator_line] + body_lines)

def generate_report(metrics, thresholds, output_path):
    """
    Generates a markdown report from the parsed metrics.
    """
    high_ccn = sorted(
        [m for m in metrics if m['ccn'] > thresholds['cyclomatic_complexity_threshold']],
        key=lambda x: x['ccn'], reverse=True
    )
    long_funcs = sorted(
        [m for m in metrics if m['nloc'] > thresholds['lines_of_code_threshold']],
        key=lambda x: x['nloc'], reverse=True
    )
    many_params = sorted(
        [m for m in metrics if m['params'] > thresholds['parameter_count_threshold']],
        key=lambda x: x['params'], reverse=True
    )

    content = ["# Code Complexity Report"]
    content.append("This report highlights functions that may be candidates for refactoring based on several complexity metrics.")

    if high_ccn:
        content.append("\n##  높은 순환 복잡성")
        content.append(f"순환 복잡성이 {thresholds['cyclomatic_complexity_threshold']}를 초과하는 함수입니다. 이 함수들은 여러 경로를 가지고 있어 테스트하고 유지 관리하기가 더 복잡할 수 있습니다.")
        headers = ["Complexity (CCN)", "Function", "File"]
        rows = [[m['ccn'], f"`{m['name']}`", m['file']] for m in high_ccn]
        content.append(generate_markdown_table(headers, rows))

    if long_funcs:
        content.append("\n## Long Functions (High NLOC)")
        content.append(f"Functions with more than {thresholds['lines_of_code_threshold']} Lines of Code (NLOC). These may be doing too much and could be broken down.")
        headers = ["Lines of Code", "Function", "File"]
        rows = [[m['nloc'], f"`{m['name']}`", m['file']] for m in long_funcs]
        content.append(generate_markdown_table(headers, rows))

    if many_params:
        content.append("\n## Excessive Parameters")
        content.append(f"Functions with more than {thresholds['parameter_count_threshold']} parameters. This could indicate that a different data structure or approach might be simpler.")
        headers = ["Parameters", "Function", "File"]
        rows = [[m['params'], f"`{m['name']}`", m['file']] for m in many_params]
        content.append(generate_markdown_table(headers, rows))
        
    if not high_ccn and not long_funcs and not many_params:
        content.append("\n✅ All functions are within the defined complexity thresholds. Great job!")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(content))
    print(f"Complexity report saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Generate a code complexity report using lizard.')
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
    output_dir = os.path.join(project_root, config['paths']['output_root'])
    report_filename = config['complexity_analysis']['report_filename']
    thresholds = config['complexity_analysis']
    
    report_path = os.path.join(output_dir, report_filename)

    csv_data = run_lizard(src_path)
    if csv_data:
        metrics = parse_lizard_output(csv_data)
        generate_report(metrics, thresholds, report_path)

if __name__ == '__main__':
    main() 