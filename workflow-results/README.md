# Workflow Results Summary Generator

This script generates an HTML summary page for Apicurio Registry QE test workflow runs.

## Overview

The Apicurio Registry testing workflow performs comprehensive quality assurance testing by:

1. **Infrastructure Setup**: Installing an OpenShift cluster on AWS
2. **Operator Installation**: Installing the Apicurio Registry operator into OpenShift
3. **Multi-Configuration Testing**: Installing multiple Apicurio Registry instances in different namespaces with various configurations
4. **Comprehensive Testing**: Running UI tests, integration tests, and DAST security scans
5. **Results Collection**: Gathering all test results into the `workflow-results` directory
6. **Cleanup**: Tearing down all resources

## Usage

### Basic Usage

```bash
cd workflow-results
python generate-workflow-summary.py <workflow-directory>
python update-index.py
```

### Example

```bash
cd workflow-results

echo "Generate a workflow summary report for a specific workflow run"
python generate-workflow-summary.py 2025-08-06-16780041188

echo "Update the main index with current workflow directories"
python update-index.py
```

## Output

The script generates an HTML file named `index.html` in the workflow run directory (e.g., `2025-08-06-16780041188/index.html`). This makes it easy to browse results directly in the workflow directory.

### Main Dashboard

A main `index.html` file in the `workflow-results` directory provides a dashboard listing all available workflow runs with:
- Workflow run dates and IDs
- Job counts and status indicators  
- Direct links to summaries and raw files

The individual workflow summary contains:

### Summary Dashboard
- **Integration Test Jobs**: Count of jobs running Maven integration tests
- **UI Test Jobs**: Count of jobs running Playwright UI tests  
- **Security Scan Jobs**: Count of jobs running DAST security scans
- **Test Results**: Pass/fail statistics for integration tests

### Detailed Sections

#### Integration Tests
- **Test Statistics**: Total, passed, failed, and skipped test counts
- **Test Suites**: Individual test suite results with execution times
- **Configuration Details**: OpenShift version, storage backend, and test type

#### UI Tests
- **Test Status**: Overall pass/fail status
- **Report Availability**: Links to detailed Playwright HTML reports when available

#### Security Scans (DAST)
- **Vulnerability Count**: Total security issues found across all scans
- **Scan Details**: Individual scan results with issue breakdowns
- **SARIF Results**: Parsed security findings in industry-standard format

## Supported Test Configurations

The script automatically parses job names to extract configuration information:

### OpenShift Versions
- `os419` → OpenShift 4.19

### Storage Backends
- `inmemory` → In-Memory storage
- `pg12`, `pg17` → PostgreSQL 12, 17
- `mysql` → MySQL
- `strimzi043`, `strimzi047` → Strimzi Kafka 0.43, 0.47

### Test Types
- `integrationtests` → Maven Surefire/Failsafe integration tests
- `uitests` → Playwright UI automation tests
- `dastscan` → RapiDAST security vulnerability scans

## File Structure Analysis

The script analyzes the following result types:

### Integration Test Results
- **Location**: `<job-dir>/test-results/failsafe-reports/`
- **Files**: 
  - `failsafe-summary.xml` - Overall test statistics
  - `TEST-*.xml` - Individual test suite results
- **Format**: Maven Surefire XML format

### UI Test Results  
- **Location**: `<job-dir>/test-results/`
- **Files**: 
  - `index.html` - Playwright HTML report
  - `raw-results/` - JSON test result data
- **Format**: Playwright HTML reports

### DAST Security Scan Results
- **Location**: `<job-dir>/dast-results/<scan-name>/`
- **Files**:
  - `*.sarif` - Security findings in SARIF format
  - `scan-status.txt` - Scan execution status
- **Format**: OWASP ZAP via RapiDAST


## Requirements

- Python 3.6+
- Standard library only (no external dependencies)

### Debug Information

The script provides verbose output during execution:
- Directory structure analysis
- File parsing progress  
- Error messages for problematic files
- Summary statistics
