#!/usr/bin/env python3
"""
Simple validation script for the index.html file.

This script performs basic checks to ensure the index.html file
is properly formatted and doesn't have common issues.

Usage:
    python validate-index.py
"""

import re
from pathlib import Path


def validate_index_html():
    """Validate the index.html file for common issues."""
    index_file = Path('index.html')
    
    if not index_file.exists():
        print("❌ Error: index.html not found")
        return False
    
    with open(index_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    issues = []
    warnings = []
    
    # Check for basic HTML structure
    if not re.search(r'<!DOCTYPE html>', content):
        issues.append("Missing DOCTYPE declaration")
    
    if not re.search(r'<html[^>]*>', content):
        issues.append("Missing <html> tag")
    
    if not re.search(r'<head>', content):
        issues.append("Missing <head> section")
    
    if not re.search(r'<body>', content):
        issues.append("Missing <body> section")
    
    # Check for JavaScript issues
    if 'getElementById(' in content:
        # Look for elements that are referenced by getElementById
        id_references = re.findall(r"getElementById\(['\"]([^'\"]+)['\"]\)", content)
        for element_id in id_references:
            if f'id="{element_id}"' not in content and f"id='{element_id}'" not in content:
                issues.append(f"JavaScript references element '{element_id}' but it's not found in HTML")
    
    # Check for workflow directories array
    if 'const workflowDirectories = [' not in content:
        issues.append("Missing workflowDirectories array in JavaScript")
    
    # Check for CSS
    if '<style>' not in content and '<link' not in content:
        warnings.append("No CSS styles found")
    
    # Check for footer timestamp
    if 'Last updated:' in content:
        timestamp_match = re.search(r'Last updated: (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', content)
        if not timestamp_match:
            warnings.append("Footer timestamp format may be incorrect")
    
    # Check for workflow data
    workflow_match = re.search(r"'(\d{4}-\d{2}-\d{2}-\d+)'", content)
    if not workflow_match:
        warnings.append("No workflow directories found in JavaScript array")
    
    # Report results
    print("🔍 Validating index.html...")
    print(f"📄 File size: {len(content):,} bytes")
    
    if issues:
        print(f"\n❌ Found {len(issues)} issue(s):")
        for issue in issues:
            print(f"  • {issue}")
    else:
        print("\n✅ No critical issues found")
    
    if warnings:
        print(f"\n⚠️  Found {len(warnings)} warning(s):")
        for warning in warnings:
            print(f"  • {warning}")
    
    # Count workflow directories
    workflow_dirs = re.findall(r"'(\d{4}-\d{2}-\d{2}-\d+)'", content)
    if workflow_dirs:
        print(f"\n📊 Found {len(workflow_dirs)} workflow directories:")
        for i, workflow in enumerate(workflow_dirs[:5]):
            print(f"  {i+1}. {workflow}")
        if len(workflow_dirs) > 5:
            print(f"  ... and {len(workflow_dirs) - 5} more")
    
    return len(issues) == 0


def main():
    """Main function."""
    success = validate_index_html()
    
    if success:
        print("\n🎉 Validation completed successfully!")
        print("💡 The index.html file should load without JavaScript errors.")
    else:
        print("\n🚨 Validation failed! Please fix the issues above.")
    
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())