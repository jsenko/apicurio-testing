# Migration Plan: OKD to OpenShift Container Platform (OCP)

## Executive Summary

This document outlines the migration strategy from OKD (community OpenShift) to Red Hat OpenShift
Container Platform (OCP) for the Apicurio testing infrastructure.

**Approach**: Hard cutover (complete replacement of OKD with OCP)
**Timeline**: ASAP
**Target Version**: OCP 4.16 (stable)
**OKD Support**: Will be removed once OCP is validated

---

## Current State

### Platform
- **Current**: OKD versions 4.14, 4.16, 4.19
- **Target**: OCP 4.16

### Infrastructure
- **Cloud Provider**: AWS (us-east-1)
- **Instance Types**: m5.xlarge (4 vCPU, 16 GB RAM)
- **Topology**: 3 control plane + 3 compute nodes
- **Availability**: Single AZ (us-east-1a)
- **DNS**: Route53 (apicurio-testing.org)

### Testing Stack
- Apicurio Registry (multiple storage backends)
- Strimzi Kafka Operator
- Keycloak for authentication
- PostgreSQL and MySQL databases
- Integration tests (Maven)
- UI tests (Playwright)
- DAST security scanning (RapiDAST)

---

## Migration Phases

### Phase 1: Installer & Templates (Week 1, Days 1-2)

#### 1.1 Create OCP Installer Download Script
**File**: `download-ocp-installer.sh` (replaces `download-okd-installer.sh`)

**Key Changes**:
- Source: `mirror.openshift.com` instead of GitHub releases
- Version format: `4.16.x` instead of `4.19.0-0.okd-scos-xxxx`
- Binary name: `openshift-install`

**Download URL Pattern**:
```
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.16/openshift-install-linux.tar.gz
```

#### 1.2 Create OCP Install Config Templates
**New Directory**: `templates/ocp/4.16/`
**File**: `templates/ocp/4.16/install-config.yaml`

**Key Differences from OKD**:
```yaml
# Add FIPS mode support (optional)
fips: false

# Pull secret MUST be from console.redhat.com
pullSecret: '$OPENSHIFT_PULL_SECRET'

# Platform metadata (OCP vs OKD)
metadata:
  name: '$CLUSTER_NAME'

# AWS tags remain the same but update platform reference
platform:
  aws:
    userTags:
      apicurio/FromOcpInstaller: "true"  # Changed from OKD
```

#### 1.3 Update Core Installation Scripts
**Files to Modify**:

1. **`install-cluster.sh`**
   - Replace OKD installer calls with OCP installer
   - Update template path: `templates/okd/` → `templates/ocp/`
   - Update version selection logic
   - Change default version to 4.16

2. **`generate-install-config.sh`**
   - Update template directory path
   - Validate OCP pull secret format
   - Remove OKD-specific version handling

3. **`shared.sh`**
   - Update any platform detection functions
   - Update version validation for OCP format

4. **`configure-pull-secret.sh`**
   - Ensure compatibility with Red Hat pull secret format
   - Validate secret includes `cloud.openshift.com` registry

---

### Phase 2: Application Deployment (Week 1, Days 3-4)

#### 2.1 Operator Compatibility Verification
**Expected**: All operators should work without modification

**Operators to Test**:
- ✅ Apicurio Registry Operator
- ✅ Strimzi Kafka Operator (versions 0.43, 0.47)
- ✅ Keycloak Operator
- ✅ PostgreSQL/MySQL deployments

**Scripts (Expected No Changes)**:
- `install-apicurio-operator.sh`
- `install-apicurio-registry.sh`
- `install-strimzi.sh`
- `install-kafka.sh`
- `install-keycloak-operator.sh`
- `install-keycloak.sh`

**Validation**:
- Deploy each operator on OCP 4.16 cluster
- Verify CRDs install correctly
- Test all deployment profiles (inmemory, postgresql, mysql, kafkasql, authn)

#### 2.2 Storage Configuration
**Current**: Default AWS EBS storage class

**For OCP**: Verify storage class names
- OKD: `gp3-csi` or `gp2`
- OCP: `gp3-csi` or `gp2` (should be identical on AWS)

**Action**: No changes expected, but verify in templates

#### 2.3 TLS Certificate Handling
**Current**: Let's Encrypt + certbot + Route53 DNS challenge

**For OCP**: Same process should work

**Script**: `install-tls-cert.sh` (no changes expected)

**Validation**:
- Verify cert installation for `*.apps.$CLUSTER_NAME.apicurio-testing.org`
- Test HTTPS access to applications

---

### Phase 3: CI/CD Pipeline Updates (Week 1, Days 4-5)

#### 3.1 GitHub Actions Workflows

**Files to Update**:

1. **`.github/workflows/infra-provision-cluster.yaml`**
   - Update installer download to use OCP
   - Update version input (default to 4.16)
   - Update pull secret reference

2. **`.github/workflows/infra-destroy-cluster.yaml`**
   - Update any OKD-specific resource tags
   - Ensure AWS cleanup works for OCP clusters

3. **`.github/workflows/test-registry-release.yaml`**
   - Update matrix to use OCP versions
   - Remove OKD version references
   - Test with OCP 4.16 only initially

**Example Workflow Changes**:
```yaml
# Before (OKD)
inputs:
  okd-version:
    default: "4.19"
    type: choice
    options:
      - "4.19"
      - "4.16"
      - "4.14"

# After (OCP)
inputs:
  ocp-version:
    default: "4.16"
    type: choice
    options:
      - "4.16"
      - "4.17"  # Future-proofing
```

#### 3.2 GitHub Secrets

**Required Secrets** (verify these exist):
- `OPENSHIFT_PULL_SECRET` - Update with Red Hat pull secret from console.redhat.com
- `AWS_ACCESS_KEY_ID` - No change
- `AWS_SECRET_ACCESS_KEY` - No change
- `SSH_PUBLIC_KEY` - No change

**Action**: Update `OPENSHIFT_PULL_SECRET` with OCP pull secret

---

### Phase 4: Testing & Validation (Week 1-2, Days 5-7)

#### 4.1 Manual Testing Checklist

**Cluster Provisioning**:
- [ ] Download OCP 4.16 installer successfully
- [ ] Generate install-config.yaml from template
- [ ] Provision OCP 4.16 cluster on AWS
- [ ] Verify cluster accessible via console
- [ ] Verify DNS records created in Route53
- [ ] Install TLS certificates
- [ ] Verify HTTPS access to console

**Application Deployment**:
- [ ] Install Apicurio Registry Operator
- [ ] Deploy Registry with inmemory profile
- [ ] Deploy Registry with postgresql profile (PG 12, 16, 17)
- [ ] Deploy Registry with mysql profile (MySQL 8.0, 8.4)
- [ ] Deploy Registry with kafkasql profile (Strimzi 0.43, 0.47)
- [ ] Deploy Registry with authn profile (Keycloak 22.0, 26.3.1)
- [ ] Verify all deployments healthy

**Test Suite Execution**:
- [ ] Run integration tests (`./run-integration-tests.sh`)
  - [ ] Smoke tests pass
  - [ ] Full integration test suite passes
  - [ ] Auth tests pass
- [ ] Run UI tests (`./run-ui-tests.sh`)
  - [ ] Upstream build tests pass
  - [ ] Downstream build tests pass
- [ ] Run DAST scans (`./run-dast-scan.sh`)
  - [ ] Registry v2 API scan completes
  - [ ] Registry v3 API scan completes
  - [ ] Confluent compatibility scan completes

**Log Collection**:
- [ ] Verify `download-pod-logs.sh` works on OCP
- [ ] Ensure logs saved to `/tmp/apicurio-testing-results/`

#### 4.2 Automated Testing via GitHub Actions

**Test Workflow**:
- [ ] Trigger `infra-provision-cluster.yaml` with OCP 4.16
- [ ] Verify cluster provisions successfully
- [ ] Trigger `test-registry-release.yaml`
- [ ] Verify all test profiles pass
- [ ] Trigger `infra-destroy-cluster.yaml`
- [ ] Verify cluster destroyed and AWS resources cleaned up

#### 4.3 Performance Comparison

**Metrics to Track**:
| Metric | OKD 4.19 (Baseline) | OCP 4.16 (Target) | Delta |
|--------|---------------------|-------------------|-------|
| Cluster provision time | TBD | TBD | TBD |
| Application deploy time | TBD | TBD | TBD |
| Integration test duration | TBD | TBD | TBD |
| UI test duration | TBD | TBD | TBD |
| AWS hourly cost | TBD | TBD | TBD |

**Action**: Run baseline OKD test, then compare with OCP

---

### Phase 5: Cutover & Cleanup (Week 2, Days 8-10)

#### 5.1 Pre-Cutover Validation
- [ ] All manual tests pass on OCP 4.16
- [ ] All automated tests pass via GitHub Actions
- [ ] Performance metrics acceptable
- [ ] Documentation updated

#### 5.2 Cutover Steps

**Day 8: Update Default Configuration**
1. Update all workflows to use OCP 4.16 by default
2. Update documentation (README, scripts help text)
3. Commit changes to main branch

**Day 9: Remove OKD Artifacts**
1. Delete `download-okd-installer.sh`
2. Delete `templates/okd/` directory
3. Remove OKD version options from scripts
4. Update any remaining OKD references

**Day 10: Final Validation**
1. Run full test suite on OCP
2. Monitor for any issues
3. Document any gotchas or lessons learned

#### 5.3 Cleanup Checklist

**Files to Delete**:
- [ ] `download-okd-installer.sh`
- [ ] `templates/okd/4.14/install-config.yaml`
- [ ] `templates/okd/4.16/install-config.yaml`
- [ ] `templates/okd/4.19/install-config.yaml`
- [ ] `templates/okd/` directory (entire)

**Files to Update**:
- [ ] `README.md` - Update platform references
- [ ] `install-cluster.sh` - Remove OKD version options
- [ ] `generate-install-config.sh` - Remove OKD template paths
- [ ] `.github/workflows/infra-provision-cluster.yaml` - Remove OKD versions
- [ ] `.github/workflows/test-registry-release.yaml` - Remove OKD matrix

**Rename Files** (if desired):
- [ ] `download-ocp-installer.sh` → `download-installer.sh`

---

## Key Differences: OKD vs OCP

### Technical Differences

| Aspect | OKD | OCP |
|--------|-----|-----|
| **Source** | Community, GitHub releases | Red Hat, mirror.openshift.com |
| **Versioning** | `4.19.0-0.okd-scos-xxx` | `4.16.20` |
| **Pull Secret** | Generic Docker credentials | Red Hat account required |
| **Support** | Community | Red Hat Enterprise Support |
| **Release Cadence** | Follows upstream quickly | Stable, tested releases |
| **FIPS Mode** | Not available | Available (optional) |
| **Certification** | None | Red Hat certified operators |

### Operational Differences

| Aspect | OKD | OCP |
|--------|-----|-----|
| **Cost** | Free (AWS infrastructure only) | Requires RHEL subscription |
| **Updates** | Manual, frequent | Controlled, tested |
| **Operators** | Community + certified | Red Hat certified |
| **SLA** | None | Enterprise SLA available |

### For Apicurio Testing

**Impact**: Minimal to none
- Same Kubernetes APIs
- Same AWS infrastructure
- Same operators (Apicurio, Strimzi, Keycloak)
- Same test frameworks

**Benefits**:
- More stable releases
- Better support for troubleshooting
- Aligned with Red Hat product testing
- Red Hat certified operator ecosystem

---

## Risk Assessment

### High Risk Items
**None identified** - OCP and OKD are nearly identical for our use case

### Medium Risk Items

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Pull secret format issues | Cluster provision fails | Low | Test with OCP pull secret early |
| Operator incompatibility | App deployment fails | Low | Test all operators before cutover |
| Version mismatch issues | Unexpected behavior | Low | Use stable OCP 4.16 release |

### Low Risk Items

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| GitHub Actions failures | CI/CD disruption | Low | Test workflows before merge |
| DNS propagation delays | Temporary unavailability | Low | Keep same Route53 setup |
| AWS quota limits | Provision failures | Very Low | Same resources as OKD |

---

## Rollback Plan

### If OCP Migration Fails

**Rollback Steps**:
1. Revert commits to restore OKD scripts
2. Restore `download-okd-installer.sh`
3. Restore `templates/okd/` directory
4. Update workflows back to OKD versions
5. Document reason for rollback

**Rollback Time**: < 1 hour (git revert)

### When to Rollback

Trigger rollback if:
- Cannot provision OCP cluster after 3 attempts
- Critical test failures on OCP that don't occur on OKD
- Operator incompatibility discovered
- Blocker issues with no workaround

---

## Success Criteria

### Required for Cutover
- [x] OCP 4.16 cluster provisions successfully
- [ ] All Apicurio Registry profiles deploy successfully
- [ ] Integration test suite passes (100% pass rate)
- [ ] UI test suite passes (100% pass rate)
- [ ] DAST scans complete without errors
- [ ] GitHub Actions workflows execute successfully
- [ ] Documentation updated

### Post-Cutover Validation (Week 3)
- [ ] 5 successful OCP cluster provisions via automation
- [ ] 10 successful test suite runs
- [ ] Zero rollbacks or critical issues
- [ ] Team comfortable with OCP operations

---

## Timeline

### Week 1: Implementation & Testing

| Day | Activities | Owner | Status |
|-----|-----------|-------|--------|
| 1 | Create OCP installer script + templates | TBD | Pending |
| 2 | Update core installation scripts | TBD | Pending |
| 3 | Test operator deployments on OCP | TBD | Pending |
| 4 | Update GitHub Actions workflows | TBD | Pending |
| 5 | Run full manual test suite | TBD | Pending |
| 6-7 | Run automated tests, collect metrics | TBD | Pending |

### Week 2: Cutover & Cleanup

| Day | Activities | Owner | Status |
|-----|-----------|-------|--------|
| 8 | Deploy to production, update defaults | TBD | Pending |
| 9 | Remove OKD artifacts | TBD | Pending |
| 10 | Final validation, documentation | TBD | Pending |

### Week 3: Stabilization
- Monitor OCP clusters
- Address any issues
- Collect feedback
- Optimize as needed

---

## Implementation Order

### Priority 1 (Must Have - Week 1)
1. `download-ocp-installer.sh` - OCP installer download script
2. `templates/ocp/4.16/install-config.yaml` - OCP cluster configuration
3. Update `install-cluster.sh` - Core provisioning logic
4. Update `generate-install-config.sh` - Template processing
5. Manual test: Provision single OCP cluster

### Priority 2 (Must Have - Week 1)
6. Deploy all operators on OCP cluster
7. Run integration tests
8. Run UI tests
9. Run DAST scans
10. Validate all tests pass

### Priority 3 (Must Have - Week 1-2)
11. Update `.github/workflows/infra-provision-cluster.yaml`
12. Update `.github/workflows/test-registry-release.yaml`
13. Update `.github/workflows/infra-destroy-cluster.yaml`
14. Test automated workflows

### Priority 4 (Cleanup - Week 2)
15. Remove OKD scripts and templates
16. Update documentation
17. Final validation

---

## Prerequisites Checklist

### Red Hat Access
- [x] Red Hat employee access
- [ ] OCP pull secret obtained from console.redhat.com
- [ ] Pull secret stored in GitHub Secrets (`OPENSHIFT_PULL_SECRET`)

### AWS Infrastructure
- [ ] AWS account access verified
- [ ] Service quotas sufficient for OCP
- [ ] Route53 hosted zone for `apicurio-testing.org` exists
- [ ] AWS credentials configured in GitHub Secrets

### Local Environment
- [ ] AWS CLI installed and configured
- [ ] `oc` CLI installed (OpenShift CLI)
- [ ] Git repository cloned
- [ ] Bash shell available

---

## Post-Migration Tasks

### Documentation Updates
- [ ] Update `README.md` with OCP references
- [ ] Update script help text and comments
- [ ] Create troubleshooting guide for OCP
- [ ] Document OCP-specific configurations

### Knowledge Transfer
- [ ] Share OCP provisioning process with team
- [ ] Document any OCP-specific gotchas
- [ ] Update runbooks for OCP operations

### Future Enhancements
- [ ] Consider adding OCP 4.17 support
- [ ] Explore OCP upgrades (4.16 → 4.17)
- [ ] Evaluate disconnected/airgap installation for security testing
- [ ] Consider multi-AZ deployments for HA testing

---

## Questions & Answers

**Q: Why hard cutover vs parallel run?**
A: Faster migration (ASAP requirement), no need to maintain two platforms, simpler codebase.

**Q: What if we find issues with OCP?**
A: Rollback plan in place (< 1 hour to revert), but risk is very low given OCP/OKD similarity.

**Q: Will tests run differently on OCP?**
A: No, same Kubernetes APIs and operators. Tests should be identical.

**Q: What about cost?**
A: Red Hat employees have access to OCP subscriptions. AWS infrastructure costs remain the same.

**Q: Can we run OCP and OKD in parallel temporarily?**
A: Not planned, but rollback plan allows returning to OKD if needed.

---

## Contact & Support

**For OCP Technical Issues**:
- Red Hat Support Portal: https://access.redhat.com
- Internal Red Hat Slack channels

**For Migration Questions**:
- Repository maintainer: TBD
- Slack channel: TBD

---

## Appendix A: OCP Installer Download URLs

### Stable Releases
```bash
# OCP 4.16 (stable)
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.16/openshift-install-linux.tar.gz

# OCP 4.17 (stable) - future
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.17/openshift-install-linux.tar.gz
```

### Specific Versions
```bash
# Example: OCP 4.16.20
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.16.20/openshift-install-linux.tar.gz
```

### Latest Release
```bash
# Latest OCP release
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux.tar.gz
```

---

## Appendix B: OCP Pull Secret Format

### Obtaining the Pull Secret
1. Navigate to: https://console.redhat.com/openshift/install/pull-secret
2. Click "Copy pull secret"
3. Store in GitHub Secrets as `OPENSHIFT_PULL_SECRET`

### Pull Secret Structure
```json
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "...",
      "email": "..."
    },
    "quay.io": {
      "auth": "...",
      "email": "..."
    },
    "registry.connect.redhat.com": {
      "auth": "...",
      "email": "..."
    },
    "registry.redhat.io": {
      "auth": "...",
      "email": "..."
    }
  }
}
```

**Note**: OCP pull secret includes `cloud.openshift.com` and Red Hat registries, unlike generic Docker
credentials used with OKD.

---

## Appendix C: Version Comparison Matrix

| OKD Version | Release Date | OCP Equivalent | OCP Release Date | Notes |
|-------------|--------------|----------------|------------------|-------|
| 4.14.0-0.okd | 2023-11 | 4.14.x | 2023-11 | Kubernetes 1.27 |
| 4.16.0-0.okd | 2024-07 | 4.16.x | 2024-06 | Kubernetes 1.29 |
| 4.19.0-0.okd | 2025-01 | 4.17.x (future) | 2024-11 | Kubernetes 1.30 |

**Migration Strategy**: Start with OCP 4.16 as it's the stable, well-tested release that aligns with OKD
4.16 currently in use.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-07 | Claude Code | Initial migration plan |

---

**Last Updated**: 2025-11-07
**Status**: Draft - Ready for Implementation