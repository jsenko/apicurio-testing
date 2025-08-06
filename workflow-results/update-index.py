#!/usr/bin/env python3
"""
Update the workflow-results index.html with current workflow directories.

This script scans the workflow-results directory for workflow run directories
and updates the JavaScript data in index.html to reflect the current state.

Usage:
    python update-index.py
"""

import os
import re
from pathlib import Path
from datetime import datetime


def scan_workflow_directories():
    """Scan for workflow directories and collect metadata."""
    workflows = []
    current_dir = Path('.')
    
    for dir_path in sorted(current_dir.iterdir(), reverse=True):
        if dir_path.is_dir() and dir_path.name not in ['__pycache__', '.git']:
            # Check if it looks like a workflow directory (YYYY-MM-DD-RUNID format)
            match = re.match(r'(\d{4})-(\d{2})-(\d{2})-(\d+)', dir_path.name)
            if match:
                year, month, day, run_id = match.groups()
                
                # Check for index.html (summary available)
                has_index = (dir_path / 'index.html').exists()
                
                # Count job directories
                job_count = len([d for d in dir_path.iterdir() if d.is_dir()])
                
                workflows.append({
                    'name': dir_path.name,
                    'year': year,
                    'month': month,
                    'day': day,
                    'run_id': run_id,
                    'has_index': has_index,
                    'job_count': job_count
                })
    
    return workflows


def update_index_html(workflows):
    """Update the index.html file with current workflow data."""
    index_file = Path('index.html')
    
    if not index_file.exists():
        print("Error: index.html not found in current directory")
        return False
    
    # Read current index.html
    with open(index_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Generate JavaScript array for workflows
    js_workflows = []
    for workflow in workflows:
        js_workflows.append(f"'{workflow['name']}'")
    
    workflows_js = ',\n                '.join(js_workflows)
    
    # Replace the workflow directories array in the JavaScript
    pattern = r'(const workflowDirectories = \[)(.*?)(\];)'
    replacement = f'\\1\n                {workflows_js}\n            \\3'
    
    updated_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Update the checkForIndex function with actual workflow data
    workflows_with_index = [w['name'] for w in workflows if w['has_index']]
    index_list_js = ', '.join([f"'{name}'" for name in workflows_with_index])
    
    # Replace the checkForIndex function
    check_for_index_pattern = r'(function checkForIndex\(workflowName\) \{.*?return )(.*?)(\;.*?\})'
    check_for_index_replacement = f'\\1[{index_list_js}].includes(workflowName)\\3'
    
    updated_content = re.sub(check_for_index_pattern, check_for_index_replacement, updated_content, flags=re.DOTALL)
    
    # Update the generation timestamp while preserving the dynamic date element
    current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    pattern = r'(Last updated: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \| Auto-generated from directory scan)'
    if re.search(pattern, updated_content):
        # Update existing timestamp
        replacement = f'Last updated: {current_time} | Auto-generated from directory scan'
        updated_content = re.sub(pattern, replacement, updated_content)
    else:
        # First time update - replace the original footer
        pattern = r'(Generated on <span id="current-date"></span>)'
        replacement = f'Last updated: {current_time} | Auto-generated from directory scan'
        updated_content = updated_content.replace('Generated on <span id="current-date"></span>', replacement)
    
    # Write updated content
    with open(index_file, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    return True


def main():
    """Main function."""
    print("Scanning workflow directories...")
    workflows = scan_workflow_directories()
    
    if not workflows:
        print("No workflow directories found.")
        return
    
    print(f"Found {len(workflows)} workflow directories:")
    for workflow in workflows[:5]:  # Show first 5
        status = "✅ Summary" if workflow['has_index'] else "📁 Raw files"
        print(f"  {workflow['name']} ({workflow['job_count']} jobs) - {status}")
    
    if len(workflows) > 5:
        print(f"  ... and {len(workflows) - 5} more")
    
    print("\nUpdating index.html...")
    if update_index_html(workflows):
        print("✅ Successfully updated index.html")
        print("🌐 Open workflow-results/index.html in your browser to view the updated listing")
    else:
        print("❌ Failed to update index.html")


if __name__ == "__main__":
    # Change to workflow-results directory if not already there
    if not Path('generate-workflow-summary.py').exists():
        if Path('workflow-results/generate-workflow-summary.py').exists():
            os.chdir('workflow-results')
        else:
            print("Error: Please run this script from the project root or workflow-results directory")
            exit(1)
    
    main()