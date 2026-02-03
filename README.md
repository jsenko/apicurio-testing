# Apicurio Registry Testing Infrastructure

Automated testing infrastructure for validating Apicurio Registry deployments on OpenShift/OKD clusters.

## Overview

This project provides comprehensive end-to-end testing for [Apicurio Registry](https://github.com/Apicurio/apicurio-registry) across multiple configurations, storage backends, and OpenShift versions.

**Test Coverage:**
- 🔢 **2 OpenShift versions** (4.20, 4.16)
- 💾 **4 storage backends** (In-memory, PostgreSQL, MySQL, KafkaSQL)
- 🔐 **Authentication** (Keycloak OAuth2/OIDC)
- 🧪 **3 test types** (UI, Integration, Security/DAST)
- ☁️ **AWS-based** cluster provisioning

## Quick Start

### Prerequisites

- AWS account with credentials configured
- GitHub account with access to this repository
- Domain with Route53 hosted zone (for TLS certificates)

### 1. Configure Secrets

Create a `secrets.env` file (gitignored):

```bash
# AWS Configuration
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# DNS Configuration
export BASE_DOMAIN="apicurio-testing.org"
export HOSTED_ZONE_ID="Z123456789"

# OpenShift Configuration
export OPENSHIFT_PULL_SECRET='{"auths": {...}}'
export SSH_PUBLIC_KEY="ssh-rsa ..."
```

### 2. Load Cache

```bash
./load-cache.sh --token $GITHUB_TOKEN
```

This downloads installers, certificates, and cluster configurations from the cache repository.

### 3. Provision Cluster

```bash
# Provision OpenShift 4.20 cluster with 6 nodes
./install-cluster.sh --cluster mytest --ocpVersion 4.20
```

### 4. Deploy Apicurio Registry

```bash
# Example: PostgreSQL backend
./install-apicurio-operator.sh --cluster mytest --version 3.1.1
./install-apicurio-registry.sh --cluster mytest --namespace testns --profile postgresql
```

### 5. Run Tests

```bash
# Integration tests
./run-integration-tests.sh --cluster mytest --namespace testns

# UI tests
./run-ui-tests.sh --cluster mytest --namespace testns

# Security scan
./run-dast-scan.sh --cluster mytest --namespace testns
```

### 6. Cleanup

```bash
./destroy-cluster.sh --cluster mytest
./save-cache.sh
```

## Deployment Profiles

Profiles define complete infrastructure stacks:

| Profile | Storage | Additional Components | Use Case |
|---------|---------|----------------------|----------|
| `inmemory` | In-memory | None | Quick testing, ephemeral |
| `postgresql` | PostgreSQL | PostgreSQL database | Production-like SQL storage |
| `mysql` | MySQL | MySQL database | MySQL compatibility testing |
| `kafkasql` | Kafka | Strimzi + Kafka cluster | Distributed storage |
| `authn` | PostgreSQL | Keycloak | Authentication testing |

**Usage:**
```bash
./install-apicurio-registry.sh --cluster mytest --namespace ns1 --profile <profile-name>
```

## GitHub Actions Workflows

### Main Release Testing

**Workflow:** `.github/workflows/test-registry-release.yaml`

Tests Apicurio Registry releases across the full matrix:

```
OpenShift 4.20 cluster (ci420)
├─ inmemory      → UI + Integration + DAST
├─ PostgreSQL 17 → UI + Integration
├─ PostgreSQL 12 → Integration (smoke)
├─ MySQL 8.4     → UI + Integration
├─ MySQL 8.0     → Integration (smoke)
├─ KafkaSQL      → UI + Integration
├─ Keycloak 26   → Integration + DAST
└─ Keycloak 22   → Integration

OpenShift 4.16 cluster (ci416)
├─ inmemory      → UI + Integration
└─ KafkaSQL      → UI + Integration
```

**Trigger manually:**
1. Go to Actions → [Test] Registry Release
2. Click "Run workflow"
3. Enter release version and test parameters

**Execution time:** ~3.5 hours for full matrix

### Other Workflows

- **test-registry-operator.yaml** - OLM operator testing
- **infra-provision-cluster.yaml** - Cluster provisioning only
- **infra-destroy-cluster.yaml** - Cluster destruction

## Project Structure

```
apicurio-testing/
├── cache/                  # Git-based cache (installers, certs, kubeconfig)
├── templates/
│   ├── ocp/               # OpenShift install-config templates
│   ├── okd/               # OKD install-config templates
│   ├── profiles/          # Registry deployment profiles
│   └── rapidast/          # DAST security scan configs
├── .github/
│   ├── workflows/         # GitHub Actions workflows
│   └── actions/           # Custom actions (commit results, logs)
├── migration-testing/     # Version 2.x → 3.x migration tests
├── docs/                  # Additional documentation
└── *.sh                   # Installation and testing scripts
```

## Key Scripts

### Cluster Management
- `install-cluster.sh` - Provision OpenShift cluster on AWS
- `destroy-cluster.sh` - Destroy cluster and cleanup resources
- `generate-install-config.sh` - Generate cluster configuration

### Registry Deployment
- `install-apicurio-operator.sh` - Install Apicurio Registry operator
- `install-apicurio-registry.sh` - Deploy Registry instance with profile
- `install-strimzi.sh` - Install Strimzi Kafka operator
- `install-kafka.sh` - Deploy Kafka cluster
- `install-keycloak.sh` - Deploy Keycloak for authentication

### Testing
- `run-integration-tests.sh` - Execute integration test suite
- `run-ui-tests.sh` - Execute UI/frontend tests
- `run-dast-scan.sh` - Execute security scanning (RapiDAST)

### Utilities
- `load-cache.sh` - Clone/pull cache repository
- `save-cache.sh` - Commit and push cache updates
- `download-pod-logs.sh` - Collect pod logs for debugging

## Common Use Cases

### Test New Registry Version

```bash
# 1. Provision cluster
./install-cluster.sh --cluster test420 --ocpVersion 4.20

# 2. Install operator
./install-apicurio-operator.sh --cluster test420 --version 3.1.1

# 3. Deploy with PostgreSQL
./install-apicurio-registry.sh --cluster test420 --namespace pg --profile postgresql

# 4. Run tests
./run-integration-tests.sh --cluster test420 --namespace pg
./run-ui-tests.sh --cluster test420 --namespace pg

# 5. Cleanup
./destroy-cluster.sh --cluster test420
```

### Test with Keycloak Authentication

```bash
# Install Keycloak operator and server
./install-keycloak-operator.sh --cluster test420 --namespace auth
./install-keycloak.sh --cluster test420 --namespace auth

# Deploy Registry with authentication
./install-apicurio-registry.sh --cluster test420 --namespace auth --profile authn

# Run auth tests
./run-integration-tests.sh --cluster test420 --namespace auth --testProfile auth
```

### Test Migration (v2.6 → v3.1)

```bash
cd migration-testing/scenario-1
./scripts/setup.sh
./scripts/migrate.sh
./scripts/verify.sh
```

## Configuration

### Environment Variables (secrets.env)

```bash
# Required for cluster provisioning
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION

# Required for cluster access
OPENSHIFT_PULL_SECRET
SSH_PUBLIC_KEY

# Required for DNS/TLS
BASE_DOMAIN
HOSTED_ZONE_ID

# Optional for private registries
DOCKER_SERVER
DOCKER_USERNAME
DOCKER_PASSWORD
DOCKER_EMAIL
```

### Cache Directory Structure

The `cache/` directory is a git repository containing:

```
cache/
├── bin/                    # OCP/OKD installers
│   ├── 4.16/
│   ├── 4.19/
│   └── 4.20/
├── certificates/           # Let's Encrypt TLS certificates
│   ├── ci416/
│   └── ci420/
└── clusters/               # Cluster state and kubeconfig
    ├── ci416/
    │   └── auth/kubeconfig
    └── ci420/
        └── auth/kubeconfig
```

## Test Results

Test results are automatically committed to a separate repository:
**apicurio-testing-results**

Results include:
- Pod logs (on failure)
- JUnit XML test reports
- HTML test reports
- DAST security scan results
- Workflow metadata and timing

## Troubleshooting

### Cluster provisioning fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify installer downloaded
ls -la cache/bin/4.20/

# Check install logs
cat cache/clusters/<cluster-name>/.openshift_install.log
```

### Registry deployment timeout

```bash
# Check operator logs
kubectl logs -n <namespace> -l name=apicurio-registry-operator

# Check registry pod status
kubectl get pods -n <namespace>
kubectl describe pod -n <namespace> <pod-name>
```

### Tests fail to connect

```bash
# Verify route exists
kubectl get route -n <namespace>

# Test connectivity
curl -k https://registry-app-<namespace>.apps.<cluster>.<domain>/apis/registry/v3/system/info
```

### Cache out of sync

```bash
# Reset cache
rm -rf cache/
./load-cache.sh --token $GITHUB_TOKEN
```

## Cost Considerations

**AWS Resources per cluster:**
- 3 × m5.xlarge control plane nodes
- 3 × m5.xlarge compute nodes
- ELB load balancers
- Route53 hosted zone
- S3 storage

**Estimated cost:** ~$1.73/hour per cluster

**Optimization tips:**
- Reuse clusters with `--skipClusterInstall` flag
- Use smaller instance types for development
- Consider spot instances for cost savings
- Always destroy clusters when done

## Contributing

When adding new test configurations:

1. Create profile in `templates/profiles/<name>/`
2. Add deployment job to workflow
3. Add test jobs (UI, integration, DAST as needed)
4. Add teardown job
5. Update this README

## Documentation

- **PROJECT_INDEX.md** - Complete project structure and entry points
- **COMPREHENSIVE_ANALYSIS.md** - Detailed technical analysis
- **SYSTEM_TESTS_ANALYSIS.md** - System test coverage analysis
- **docs/Operator-Testing.md** - OLM operator testing guide
- **docs/Extra-Tests.md** - Additional testing procedures
- **migration-testing/ANALYSIS.md** - Migration testing guide

## Support

- **Issues:** Report issues in the [GitHub Issues](https://github.com/Apicurio/apicurio-testing/issues)
- **Discussions:** Use GitHub Discussions for questions
- **Slack:** #apicurio on CNCF Slack

## License

[Apache License 2.0](LICENSE)

## Related Projects

- [Apicurio Registry](https://github.com/Apicurio/apicurio-registry) - Main Registry repository
- [Apicurio Registry Operator](https://github.com/Apicurio/apicurio-registry-operator) - Kubernetes operator
- [Strimzi](https://strimzi.io/) - Kafka on Kubernetes
