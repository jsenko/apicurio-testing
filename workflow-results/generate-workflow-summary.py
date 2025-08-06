#!/usr/bin/env python3
"""
Apicurio Registry Workflow Results Summary Generator

This script generates an HTML summary for a single workflow run from the workflow-results directory.
Each subdirectory in workflow-results contains all results from a single GitHub workflow execution.

The workflow typically includes:
1. OpenShift cluster setup on AWS
2. Apicurio Registry operator installation
3. Multiple Apicurio Registry instances with different configurations
4. UI tests, integration tests, and DAST scans
5. Results collection and teardown

Usage:
    python generate-workflow-summary.py <workflow-results-directory>

Example:
    python generate-workflow-summary.py workflow-results/2025-08-06-16780041188
"""

import os
import sys
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import re
import html


class WorkflowSummaryGenerator:
    """Generates HTML summary for Apicurio Registry workflow test results."""
    
    def __init__(self, workflow_dir: str):
        self.workflow_dir = Path(workflow_dir)
        self.workflow_name = self.workflow_dir.name
        self.results = {}
        
        # Extract date and run ID from directory name (format: YYYY-MM-DD-RUNID)
        match = re.match(r'(\d{4}-\d{2}-\d{2})-(\d+)', self.workflow_name)
        if match:
            self.date = match.group(1)
            self.run_id = match.group(2)
        else:
            self.date = "Unknown"
            self.run_id = "Unknown"
    
    def analyze_results(self):
        """Analyze all test results in the workflow directory."""
        print(f"Analyzing workflow results in: {self.workflow_dir}")
        
        if not self.workflow_dir.exists():
            raise FileNotFoundError(f"Workflow directory not found: {self.workflow_dir}")
        
        # Find all job result directories
        for job_dir in self.workflow_dir.iterdir():
            if job_dir.is_dir():
                job_name = job_dir.name
                print(f"Processing job: {job_name}")
                
                job_results = {
                    'name': job_name,
                    'integration_tests': None,
                    'ui_tests': None,
                    'dast_scans': None,
                    'pod_logs': None,
                    'config_info': self._extract_config_info(job_name)
                }
                
                # Analyze integration tests
                if (job_dir / 'test-results').exists():
                    if job_name.endswith('_integrationtests'):
                        job_results['integration_tests'] = self._analyze_integration_tests(job_dir / 'test-results')
                    elif job_name.endswith('_uitests'):
                        job_results['ui_tests'] = self._analyze_ui_tests(job_dir / 'test-results')
                
                # Analyze DAST scans
                if (job_dir / 'dast-results').exists():
                    job_results['dast_scans'] = self._analyze_dast_scans(job_dir / 'dast-results')
                
                # Check for pod logs
                if (job_dir / 'pod-logs').exists():
                    job_results['pod_logs'] = self._analyze_pod_logs(job_dir / 'pod-logs')
                
                self.results[job_name] = job_results
    
    def _extract_config_info(self, job_name: str) -> Dict[str, str]:
        """Extract configuration information from job name."""
        # Job names follow pattern: os419_<storage>_<test_type>
        # Examples: os419_inmemory_uitests, os419_pg17_integrationtests, os419_strimzi047
        parts = job_name.split('_')
        
        config = {
            'openshift_version': '',
            'storage_type': '',
            'test_type': '',
            'description': ''
        }
        
        if len(parts) >= 2:
            # Extract OpenShift version (e.g., os419 -> 4.19)
            os_match = re.match(r'os(\d)(\d+)', parts[0])
            if os_match:
                config['openshift_version'] = f"{os_match.group(1)}.{os_match.group(2)}"
            
            # Extract storage/config type
            storage_part = parts[1]
            if 'inmemory' in storage_part:
                config['storage_type'] = 'In-Memory'
            elif 'pg' in storage_part:
                pg_match = re.match(r'pg(\d+)', storage_part)
                if pg_match:
                    config['storage_type'] = f'PostgreSQL {pg_match.group(1)}'
            elif 'mysql' in storage_part:
                config['storage_type'] = 'MySQL'
            elif 'strimzi' in storage_part:
                strimzi_match = re.match(r'strimzi(\d+)', storage_part)
                if strimzi_match:
                    version = strimzi_match.group(1)
                    config['storage_type'] = f'Strimzi Kafka 0.{version[:2]}.{version[2:]}'
            elif 'authn' in storage_part:
                config['storage_type'] = 'Authentication Tests'
            else:
                config['storage_type'] = storage_part.title()
            
            # Extract test type
            if len(parts) >= 3:
                test_type = parts[2]
                if 'integrationtests' in test_type:
                    config['test_type'] = 'Integration Tests'
                elif 'uitests' in test_type:
                    config['test_type'] = 'UI Tests'
                elif 'dastscan' in test_type:
                    config['test_type'] = 'DAST Security Scan'
                else:
                    config['test_type'] = test_type.replace('tests', ' Tests').title()
            
            # Generate description
            if config['test_type']:
                config['description'] = f"{config['test_type']} on OpenShift {config['openshift_version']} with {config['storage_type']}"
            else:
                config['description'] = f"Tests on OpenShift {config['openshift_version']} with {config['storage_type']}"
        
        return config
    
    def _analyze_integration_tests(self, test_dir: Path) -> Dict:
        """Analyze Maven Surefire/Failsafe integration test results."""
        results = {
            'type': 'integration',
            'summary': {'total': 0, 'passed': 0, 'failed': 0, 'skipped': 0, 'errors': 0},
            'test_suites': [],
            'status': 'unknown'
        }
        
        # Look for failsafe-reports directory
        failsafe_dir = test_dir / 'failsafe-reports'
        if failsafe_dir.exists():
            # Parse failsafe-summary.xml for overall results
            summary_file = failsafe_dir / 'failsafe-summary.xml'
            if summary_file.exists():
                try:
                    tree = ET.parse(summary_file)
                    root = tree.getroot()
                    results['summary']['total'] = int(root.find('completed').text or 0)
                    results['summary']['errors'] = int(root.find('errors').text or 0)
                    results['summary']['failed'] = int(root.find('failures').text or 0)
                    results['summary']['skipped'] = int(root.find('skipped').text or 0)
                    results['summary']['passed'] = (results['summary']['total'] - 
                                                   results['summary']['failed'] - 
                                                   results['summary']['errors'] - 
                                                   results['summary']['skipped'])
                except Exception as e:
                    print(f"Error parsing failsafe summary: {e}")
            
            # Parse individual test result XML files
            for xml_file in failsafe_dir.glob('TEST-*.xml'):
                try:
                    tree = ET.parse(xml_file)
                    root = tree.getroot()
                    
                    suite_info = {
                        'name': root.get('name', 'Unknown'),
                        'tests': int(root.get('tests', 0)),
                        'failures': int(root.get('failures', 0)),
                        'errors': int(root.get('errors', 0)),
                        'skipped': int(root.get('skipped', 0)),
                        'time': float(root.get('time', 0))
                    }
                    suite_info['passed'] = suite_info['tests'] - suite_info['failures'] - suite_info['errors'] - suite_info['skipped']
                    results['test_suites'].append(suite_info)
                except Exception as e:
                    print(f"Error parsing test file {xml_file}: {e}")
        
        # Determine overall status
        if results['summary']['total'] > 0:
            if results['summary']['failed'] == 0 and results['summary']['errors'] == 0:
                results['status'] = 'passed'
            else:
                results['status'] = 'failed'
        
        return results
    
    def _analyze_ui_tests(self, test_dir: Path) -> Dict:
        """Analyze Playwright UI test results."""
        results = {
            'type': 'ui',
            'summary': {'total': 0, 'passed': 0, 'failed': 0, 'skipped': 0, 'flaky': 0},
            'status': 'unknown',
            'report_available': False
        }
        
        # First try to read results.json for accurate test counts
        results_json_path = test_dir / 'results.json'
        if results_json_path.exists():
            try:
                with open(results_json_path, 'r', encoding='utf-8') as f:
                    json_data = json.load(f)
                
                # Extract stats from the JSON file
                if 'stats' in json_data:
                    stats = json_data['stats']
                    results['summary']['total'] = stats.get('expected', 0) + stats.get('unexpected', 0) + stats.get('skipped', 0)
                    results['summary']['passed'] = stats.get('expected', 0)  # Expected means passed
                    results['summary']['failed'] = stats.get('unexpected', 0)  # Unexpected means failed
                    results['summary']['skipped'] = stats.get('skipped', 0)
                    results['summary']['flaky'] = stats.get('flaky', 0)
                    
                    # Add timing information
                    results['duration'] = stats.get('duration', 0) / 1000  # Convert to seconds
                    results['start_time'] = stats.get('startTime', '')
                    
                    # Determine overall status based on actual results
                    if results['summary']['failed'] > 0:
                        results['status'] = 'failed'
                    elif results['summary']['passed'] > 0:
                        results['status'] = 'passed'
                    elif results['summary']['skipped'] > 0:
                        results['status'] = 'skipped'
                    else:
                        results['status'] = 'no_tests'
                        
                    print(f"UI test results from JSON: {results['summary']['passed']} passed, {results['summary']['failed']} failed, {results['summary']['skipped']} skipped, {results['summary']['flaky']} flaky")
                
                # Extract detailed test suite information
                results['test_suites'] = []
                if 'suites' in json_data:
                    for suite in json_data['suites']:
                        suite_info = {
                            'name': suite.get('title', 'Unknown'),
                            'file': suite.get('file', ''),
                            'specs': []
                        }
                        
                        # Extract individual test specs
                        for spec in suite.get('specs', []):
                            spec_info = {
                                'title': spec.get('title', 'Unknown Test'),
                                'status': 'passed' if spec.get('ok', False) else 'failed',
                                'duration': 0,
                                'project': ''
                            }
                            
                            # Get timing and project info from test results
                            for test in spec.get('tests', []):
                                for result in test.get('results', []):
                                    spec_info['duration'] += result.get('duration', 0)
                                    spec_info['project'] = result.get('projectName', 'chromium')
                            
                            spec_info['duration'] = spec_info['duration'] / 1000  # Convert to seconds
                            suite_info['specs'].append(spec_info)
                        
                        results['test_suites'].append(suite_info)
                    
            except Exception as e:
                print(f"Error reading UI test results.json: {e}")
                # Fall back to HTML parsing if JSON fails
                return self._analyze_ui_tests_from_html(test_dir)
        else:
            # Fall back to HTML parsing if results.json doesn't exist
            print(f"results.json not found in {test_dir}, falling back to HTML parsing")
            return self._analyze_ui_tests_from_html(test_dir)
        
        # Check if HTML report is available for linking
        if (test_dir / 'index.html').exists():
            results['report_available'] = True
        
        return results
    
    def _analyze_ui_tests_from_html(self, test_dir: Path) -> Dict:
        """Analyze Playwright UI test results from HTML report (fallback method)."""
        results = {
            'type': 'ui',
            'summary': {'total': 0, 'passed': 0, 'failed': 0, 'skipped': 0, 'flaky': 0},
            'status': 'unknown',
            'report_available': False
        }
        
        # Check for Playwright HTML report
        if (test_dir / 'index.html').exists():
            results['report_available'] = True
            
            # Try to extract test counts from HTML report
            try:
                with open(test_dir / 'index.html', 'r', encoding='utf-8') as f:
                    content = f.read()
                
                import re
                
                # Look for counter spans with numbers - Playwright uses this pattern
                counter_matches = re.findall(r'counter[^>]*>(\d+)', content)
                
                if len(counter_matches) >= 5:
                    # Playwright typically shows: All, Passed, Failed, Flaky, Skipped
                    results['summary']['total'] = int(counter_matches[0])
                    results['summary']['passed'] = int(counter_matches[1])
                    results['summary']['failed'] = int(counter_matches[2])
                    results['summary']['flaky'] = int(counter_matches[3])
                    results['summary']['skipped'] = int(counter_matches[4])
                    
                    # Determine overall status
                    if results['summary']['failed'] > 0:
                        results['status'] = 'failed'
                    elif results['summary']['passed'] > 0:
                        results['status'] = 'passed'
                    elif results['summary']['skipped'] > 0:
                        results['status'] = 'skipped'
                    else:
                        results['status'] = 'no_tests'
                else:
                    # Fallback: basic text search
                    if 'failed' in content.lower():
                        results['status'] = 'failed'
                    elif 'passed' in content.lower():
                        results['status'] = 'passed'
                    else:
                        results['status'] = 'unknown'
                        
            except Exception as e:
                print(f"Error analyzing UI test HTML report: {e}")
                results['status'] = 'error'
        
        return results
    
    def _analyze_dast_scans(self, dast_dir: Path) -> Dict:
        """Analyze DAST (RapiDAST) security scan results."""
        results = {
            'type': 'dast',
            'scans': [],
            'total_issues': 0,
            'status': 'unknown'
        }
        
        # Look for scan result directories
        for scan_dir in dast_dir.iterdir():
            if scan_dir.is_dir():
                scan_info = {
                    'name': scan_dir.name,
                    'issues': [],
                    'status': 'unknown',
                    'zap_report_path': None
                }
                
                # Look for ZAP report - search for zap-report.html recursively
                zap_report_files = list(scan_dir.rglob('zap-report.html'))
                if zap_report_files:
                    # Use the first found ZAP report and make path relative to dast_dir
                    zap_report_path = zap_report_files[0]
                    scan_info['zap_report_path'] = str(zap_report_path.relative_to(dast_dir))
                    print(f"Found ZAP report for {scan_dir.name}: {scan_info['zap_report_path']}")
                
                # Look for SARIF results
                for sarif_dir in scan_dir.rglob('*.sarif'):
                    try:
                        with open(sarif_dir, 'r') as f:
                            sarif_data = json.load(f)
                        
                        # Extract issues from SARIF format
                        if 'runs' in sarif_data:
                            for run in sarif_data['runs']:
                                if 'results' in run:
                                    scan_info['issues'].extend(run['results'])
                        
                        scan_info['status'] = 'completed'
                    except Exception as e:
                        print(f"Error parsing SARIF file {sarif_dir}: {e}")
                
                # Check for scan status file
                status_file = scan_dir / 'scan-status.txt'
                if status_file.exists():
                    try:
                        with open(status_file, 'r') as f:
                            status_content = f.read().strip()
                        if 'no results' in status_content.lower():
                            scan_info['status'] = 'no_results'
                    except Exception as e:
                        print(f"Error reading scan status: {e}")
                
                results['scans'].append(scan_info)
        
        # Calculate totals
        results['total_issues'] = sum(len(scan['issues']) for scan in results['scans'])
        
        # Determine overall status
        if results['scans']:
            if results['total_issues'] == 0:
                results['status'] = 'clean'
            else:
                results['status'] = 'issues_found'
        
        return results
    
    def _analyze_pod_logs(self, logs_dir: Path) -> Dict:
        """Analyze Kubernetes pod logs."""
        results = {
            'type': 'logs',
            'log_files': [],
            'total_size': 0
        }
        
        for log_file in logs_dir.rglob('*.log'):
            try:
                file_size = log_file.stat().st_size
                results['log_files'].append({
                    'name': log_file.name,
                    'path': str(log_file.relative_to(logs_dir)),
                    'size': file_size
                })
                results['total_size'] += file_size
            except Exception as e:
                print(f"Error analyzing log file {log_file}: {e}")
        
        return results
    
    def generate_html(self) -> str:
        """Generate HTML summary report."""
        
        # Count job types
        integration_jobs = [job for job in self.results.values() if job['integration_tests']]
        ui_jobs = [job for job in self.results.values() if job['ui_tests']]
        dast_jobs = [job for job in self.results.values() if job['dast_scans']]
        
        # Calculate overall statistics
        total_integration_tests = sum(job['integration_tests']['summary']['total'] for job in integration_jobs)
        passed_integration_tests = sum(job['integration_tests']['summary']['passed'] for job in integration_jobs)
        failed_integration_tests = sum(job['integration_tests']['summary']['failed'] for job in integration_jobs)
        
        total_dast_issues = sum(job['dast_scans']['total_issues'] for job in dast_jobs)
        
        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Apicurio Registry Test Results - {self.workflow_name}</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }}
        
        .header h1 {{
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }}
        
        .header .subtitle {{
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.2em;
        }}
        
        .summary-cards {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }}
        
        .card {{
            background: white;
            border-radius: 8px;
            padding: 25px;
            text-align: center;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            border-left: 4px solid #667eea;
        }}
        
        .card.success {{ border-left-color: #28a745; }}
        .card.warning {{ border-left-color: #ffc107; }}
        .card.danger {{ border-left-color: #dc3545; }}
        .card.info {{ border-left-color: #17a2b8; }}
        
        .card-number {{
            font-size: 2.5em;
            font-weight: bold;
            margin: 0;
        }}
        
        .card-label {{
            color: #666;
            margin: 5px 0 0 0;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 0.5px;
        }}
        
        .main-content {{
            padding: 30px;
        }}
        
        .section {{
            margin-bottom: 40px;
        }}
        
        .section-title {{
            font-size: 1.8em;
            margin-bottom: 20px;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }}
        
        .job-grid {{
            display: grid;
            gap: 20px;
        }}
        
        .job-card {{
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }}
        
        .job-header {{
            background: #f8f9fa;
            padding: 15px 20px;
            border-bottom: 1px solid #ddd;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        
        .job-title {{
            font-weight: bold;
            color: #333;
        }}
        
        .job-config {{
            font-size: 0.9em;
            color: #666;
        }}
        
        .status-badge {{
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            text-transform: uppercase;
        }}
        
        .status-passed {{ background: #d4edda; color: #155724; }}
        .status-failed {{ background: #f8d7da; color: #721c24; }}
        .status-warning {{ background: #fff3cd; color: #856404; }}
        .status-unknown {{ background: #e2e3e5; color: #383d41; }}
        
        .status-section {{
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        
        .report-icon {{
            text-decoration: none;
            font-size: 1.1em;
            opacity: 0.7;
            transition: opacity 0.2s;
        }}
        
        .report-icon:hover {{
            opacity: 1;
        }}
        
        .job-content {{
            padding: 20px;
        }}
        
        .test-results {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }}
        
        .test-stat {{
            text-align: center;
            padding: 10px;
            border-radius: 5px;
            background: #f8f9fa;
        }}
        
        .test-stat-number {{
            font-size: 1.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }}
        
        .test-stat-label {{
            font-size: 0.8em;
            color: #666;
            text-transform: uppercase;
        }}
        
        .passed {{ color: #28a745; }}
        .failed {{ color: #dc3545; }}
        .skipped {{ color: #6c757d; }}
        .flaky {{ color: #ffc107; }}
        .total {{ color: #007bff; }}
        
        .no-results {{
            text-align: center;
            color: #666;
            font-style: italic;
            padding: 20px;
        }}
        
        .footer {{
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #ddd;
        }}
        
        .expandable {{
            cursor: pointer;
        }}
        
        .expandable:hover {{
            background: #f8f9fa;
        }}
        
        .details {{
            display: none;
            padding: 15px;
            background: #f8f9fa;
            border-top: 1px solid #ddd;
        }}
        
        .details.show {{
            display: block;
        }}
        
        .suite-list {{
            margin-top: 15px;
        }}
        
        .suite-item {{
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }}
        
        .suite-name {{
            font-family: monospace;
            font-size: 0.9em;
        }}
        
        .suite-stats {{
            font-size: 0.9em;
        }}
        
        .suite-header {{
            font-weight: bold;
            margin: 10px 0 5px 0;
            color: #333;
            border-bottom: 1px solid #eee;
            padding-bottom: 3px;
        }}
        
        .test-timing {{
            margin-bottom: 15px;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
            font-size: 0.9em;
        }}
        
        .no-details {{
            text-align: center;
            color: #666;
            font-style: italic;
            padding: 15px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Apicurio Registry Test Results</h1>
            <div class="subtitle">Workflow Run: {self.workflow_name} | Date: {self.date}</div>
        </div>
        
        <div class="summary-cards">
            <div class="card success">
                <div class="card-number">{len(integration_jobs)}</div>
                <div class="card-label">Integration Test Jobs</div>
            </div>
            <div class="card info">
                <div class="card-number">{len(ui_jobs)}</div>
                <div class="card-label">UI Test Jobs</div>
            </div>
            <div class="card warning">
                <div class="card-number">{len(dast_jobs)}</div>
                <div class="card-label">Security Scan Jobs</div>
            </div>
            <div class="card {'danger' if failed_integration_tests > 0 else 'success'}">
                <div class="card-number">{passed_integration_tests}/{total_integration_tests}</div>
                <div class="card-label">Integration Tests Passed</div>
            </div>
        </div>
        
        <div class="main-content">
"""

        # Integration Tests Section
        if integration_jobs:
            html_content += f"""
            <div class="section">
                <h2 class="section-title">Integration Tests</h2>
                <div class="job-grid">
"""
            for job in integration_jobs:
                tests = job['integration_tests']
                status = 'passed' if tests['status'] == 'passed' else 'failed' if tests['status'] == 'failed' else 'unknown'
                
                html_content += f"""
                    <div class="job-card">
                        <div class="job-header expandable" onclick="toggleDetails('{job['name']}_integration')">
                            <div>
                                <div class="job-title">{job['name']}</div>
                                <div class="job-config">{html.escape(job['config_info']['description'])}</div>
                            </div>
                            <span class="status-badge status-{status}">{status}</span>
                        </div>
                        <div class="job-content">
                            <div class="test-results">
                                <div class="test-stat">
                                    <div class="test-stat-number total">{tests['summary']['total']}</div>
                                    <div class="test-stat-label">Total</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number passed">{tests['summary']['passed']}</div>
                                    <div class="test-stat-label">Passed</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number failed">{tests['summary']['failed']}</div>
                                    <div class="test-stat-label">Failed</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number skipped">{tests['summary']['skipped']}</div>
                                    <div class="test-stat-label">Skipped</div>
                                </div>
                            </div>
                        </div>
                        <div id="{job['name']}_integration" class="details">
                            <h4>Test Suites:</h4>
                            <div class="suite-list">
"""
                for suite in tests['test_suites']:
                    suite_status = 'passed' if suite['failures'] == 0 and suite['errors'] == 0 else 'failed'
                    html_content += f"""
                                <div class="suite-item">
                                    <span class="suite-name">{html.escape(suite['name'].split('.')[-1])}</span>
                                    <span class="suite-stats {suite_status}">
                                        {suite['passed']}/{suite['tests']} passed ({suite['time']:.1f}s)
                                    </span>
                                </div>
"""
                html_content += """
                            </div>
                        </div>
                    </div>
"""
            html_content += """
                </div>
            </div>
"""

        # UI Tests Section
        if ui_jobs:
            html_content += f"""
            <div class="section">
                <h2 class="section-title">UI Tests</h2>
                <div class="job-grid">
"""
            for job in ui_jobs:
                tests = job['ui_tests']
                status = tests['status'] if tests['status'] != 'unknown' else 'unknown'
                
                # Map status to appropriate badge class
                status_class_map = {
                    'passed': 'passed',
                    'failed': 'failed', 
                    'skipped': 'warning',
                    'no_tests': 'warning',
                    'error': 'failed',
                    'unknown': 'unknown'
                }
                status_class = status_class_map.get(status, 'unknown')
                
                # Generate status section with icon to the left of the label
                if tests['report_available']:
                    status_section = f'''<div class="status-section">
                                <a href="{job["name"]}/test-results/index.html" target="_blank" class="report-icon" title="View Playwright Report">📊</a>
                                <span class="status-badge status-{status_class}">{status.upper()}</span>
                            </div>'''
                else:
                    status_section = f'<span class="status-badge status-{status_class}">{status.upper()}</span>'
                
                html_content += f"""
                    <div class="job-card">
                        <div class="job-header expandable" onclick="toggleDetails('{job['name']}_ui')">
                            <div>
                                <div class="job-title">{job['name']}</div>
                                <div class="job-config">{html.escape(job['config_info']['description'])}</div>
                            </div>
                            {status_section}
                        </div>
                        <div class="job-content">
"""
                
                if tests['report_available']:
                    summary = tests['summary']
                    html_content += f"""
                            <div class="test-results">
                                <div class="test-stat">
                                    <div class="test-stat-number total">{summary['total']}</div>
                                    <div class="test-stat-label">Total</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number passed">{summary['passed']}</div>
                                    <div class="test-stat-label">Passed</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number failed">{summary['failed']}</div>
                                    <div class="test-stat-label">Failed</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number flaky">{summary['flaky']}</div>
                                    <div class="test-stat-label">Flaky</div>
                                </div>
                                <div class="test-stat">
                                    <div class="test-stat-number skipped">{summary['skipped']}</div>
                                    <div class="test-stat-label">Skipped</div>
                                </div>
                            </div>
"""
                else:
                    html_content += '<p class="no-results">No detailed results available</p>'
                    
                html_content += """
                        </div>
"""
                
                # Add expandable details section
                html_content += f"""
                        <div id="{job['name']}_ui" class="details">
                            <h4>Test Details:</h4>
"""
                
                # Add timing information if available
                if 'duration' in tests and tests['duration'] > 0:
                    html_content += f"""
                            <div class="test-timing">
                                <strong>Total Duration:</strong> {tests['duration']:.1f}s
                            </div>
"""
                
                # Add test suites information if available
                if 'test_suites' in tests and tests['test_suites']:
                    html_content += """
                            <div class="suite-list">
"""
                    for suite in tests['test_suites']:
                        html_content += f"""
                                <div class="suite-header">
                                    <strong>{html.escape(suite['name'])}</strong>
                                </div>
"""
                        for spec in suite['specs']:
                            spec_status_class = 'passed' if spec['status'] == 'passed' else 'failed'
                            html_content += f"""
                                <div class="suite-item">
                                    <span class="suite-name">{html.escape(spec['title'])}</span>
                                    <span class="suite-stats {spec_status_class}">
                                        {spec['status']} ({spec['duration']:.2f}s) - {spec['project']}
                                    </span>
                                </div>
"""
                    html_content += """
                            </div>
"""
                else:
                    html_content += '<p class="no-details">No detailed test information available</p>'
                    
                html_content += """
                        </div>
                    </div>
"""
            html_content += """
                </div>
            </div>
"""

        # DAST Security Scans Section
        if dast_jobs:
            html_content += f"""
            <div class="section">
                <h2 class="section-title">Security Scans (DAST)</h2>
                <div class="job-grid">
"""
            for job in dast_jobs:
                scans = job['dast_scans']
                status = scans['status'] if scans['status'] != 'unknown' else 'unknown'
                status_class = 'success' if status == 'clean' else 'warning' if status == 'issues_found' else 'unknown'
                
                html_content += f"""
                    <div class="job-card">
                        <div class="job-header expandable" onclick="toggleDetails('{job['name']}_dast')">
                            <div>
                                <div class="job-title">{job['name']}</div>
                                <div class="job-config">{html.escape(job['config_info']['description'])}</div>
                            </div>
                            <span class="status-badge status-{status_class}">{status.replace('_', ' ').title()}</span>
                        </div>
                        <div class="job-content">
                            <p><strong>Total Issues Found:</strong> {scans['total_issues']}</p>
                            <p><strong>Scans Completed:</strong> {len(scans['scans'])}</p>
                        </div>
                        <div id="{job['name']}_dast" class="details">
                            <h4>Scan Details:</h4>
"""
                for scan in scans['scans']:
                    # Create status section with ZAP report link if available
                    scan_status_section = f"""
                                <span class="suite-stats">{len(scan['issues'])} issues</span>"""
                    
                    if scan.get('zap_report_path'):
                        scan_status_section = f"""
                                <div class="status-section">
                                    <a href="{job["name"]}/dast-results/{scan['zap_report_path']}" target="_blank" class="report-icon" title="View ZAP Security Report">🛡️</a>
                                    <span class="suite-stats">{len(scan['issues'])} issues</span>
                                </div>"""
                    
                    html_content += f"""
                            <div class="suite-item">
                                <span class="suite-name">{html.escape(scan['name'])}</span>
                                {scan_status_section}
                            </div>
"""
                html_content += """
                        </div>
                    </div>
"""
            html_content += """
                </div>
            </div>
"""



        html_content += f"""
        </div>
        
        <div class="footer">
            <p>Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | 
            Workflow Run ID: {self.run_id} | 
            Total Jobs: {len(self.results)}</p>
        </div>
    </div>
    
    <script>
        function toggleDetails(id) {{
            const element = document.getElementById(id);
            if (element.classList.contains('show')) {{
                element.classList.remove('show');
            }} else {{
                element.classList.add('show');
            }}
        }}
    </script>
</body>
</html>"""
        
        return html_content
    
    def save_html(self, output_file: str = None):
        """Save the HTML summary to a file."""
        if output_file is None:
            # Save as index.html in the workflow directory
            output_file = self.workflow_dir / "index.html"
        
        html_content = self.generate_html()
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"HTML summary saved to: {output_file}")
        return str(output_file)


def main():
    """Main function to run the script."""
    if len(sys.argv) != 2:
        print("Usage: python generate-workflow-summary.py <workflow-directory>")
        print("\nExample:")
        print("  python generate-workflow-summary.py 2025-08-06-16780041188")
        print("\nAvailable workflow directories:")
        
        # List available directories (script is now in workflow-results directory)
        current_dir = Path(".")
        workflow_dirs = []
        for dir_path in sorted(current_dir.iterdir()):
            if dir_path.is_dir() and dir_path.name not in ['__pycache__', '.git']:
                # Check if it looks like a workflow directory (YYYY-MM-DD-RUNID format)
                if re.match(r'\d{4}-\d{2}-\d{2}-\d+', dir_path.name):
                    workflow_dirs.append(dir_path)
        
        if workflow_dirs:
            for dir_path in workflow_dirs:
                print(f"  {dir_path.name}")
        else:
            print("  No workflow directories found in current directory")
        
        sys.exit(1)
    
    workflow_dir = sys.argv[1]
    
    try:
        # Generate summary
        generator = WorkflowSummaryGenerator(workflow_dir)
        generator.analyze_results()
        output_file = generator.save_html()
        
        print(f"\n✅ Successfully generated HTML summary!")
        print(f"📁 Output file: {output_file}")
        print(f"🌐 Open in browser: file://{os.path.abspath(output_file)}")
        
    except Exception as e:
        print(f"❌ Error generating summary: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()