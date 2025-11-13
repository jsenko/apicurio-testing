# Scenario 1 Test Plan Evaluation

## Executive Summary

The proposed migration test scenario is **well-designed and comprehensive**. It provides an excellent foundation
for testing the basic migration path from Apicurio Registry 2.6.x to 3.1.x.

**Overall Assessment**: ✅ **APPROVED** with suggested enhancements

---

## Strengths of the Proposed Plan

### 1. Realistic Infrastructure Simulation
- Using nginx as a load balancer accurately simulates production environments
- Separate PostgreSQL instances prevent data contamination
- Different ports allow parallel running for comparison

### 2. Comprehensive Data Coverage
- Multiple artifact types (Avro, Protobuf, JSON, OpenAPI, AsyncAPI)
- Multiple versions per artifact
- Global and artifact-specific rules
- Artifact references
- Metadata (labels, properties, descriptions)

### 3. Backward Compatibility Focus
- Testing v2 API against v3 registry is crucial
- Ensures existing clients continue to work post-migration
- Validates the deprecation path

### 4. Clear Success Criteria
- Quantifiable validation points
- Binary pass/fail for each check
- Detailed logging for debugging

### 5. Progressive Validation
- Validate before migration (baseline)
- Validate after import (data integrity)
- Validate v2 API compatibility
- Validate v3 API functionality

### 6. Appropriate Scope
- Focused on core migration process
- Excludes authentication (saved for scenario 2)
- Excludes advanced storage (saved for scenario 4)
- Good starting point for more complex scenarios

---

## Suggested Enhancements

### High Priority

#### 1. Global Rules Testing (ADDED to plan)
**Current**: Plan mentions global rules
**Enhancement**: Ensure comprehensive rule testing

**Test Cases**:
- VALIDITY rule with FULL configuration
- COMPATIBILITY rule with BACKWARD configuration
- Verify rules are enforced after migration
- Test rule violation handling

#### 2. Artifact References Testing (ADDED to plan)
**Current**: Plan mentions references
**Enhancement**: Explicit reference testing

**Test Cases**:
- Protobuf with imports to other Protobuf schemas
- JSON Schema with $ref to other schemas
- Verify references resolve after migration
- Test dereferencing functionality

#### 3. Content Hash Validation (ADDED to plan)
**Current**: Not explicitly mentioned
**Enhancement**: Test content deduplication

**Test Cases**:
- Create identical content in different versions
- Verify content hash is same
- Retrieve content by hash
- Validate hash preservation after migration

#### 4. Version Comments (ADDED to plan)
**Current**: Plan mentions version metadata
**Enhancement**: Explicit comment testing

**Test Cases**:
- Add comments to specific versions
- Verify comments preserved after migration
- Test comment ownership

### Medium Priority

#### 5. Artifact Count Comparison Script
**Current**: Manual comparison in validation
**Enhancement**: Automated comparison tool

**Implementation**:
```bash
./scripts/compare-registries.sh \
  --source=http://localhost:8080/apis/registry/v2 \
  --target=http://localhost:8081/apis/registry/v3 \
  --output=data/comparison.json
```

**Output**:
- Side-by-side artifact counts
- Missing artifacts
- Extra artifacts
- Version count differences
- Metadata differences

#### 6. Health Check Automation
**Current**: Manual curl commands
**Enhancement**: Reusable health check script

**Implementation**:
```bash
./scripts/wait-for-health.sh <url> <timeout>
```

**Features**:
- Retry with exponential backoff
- Clear success/failure messages
- Timeout handling
- Exit code for script chaining

#### 7. Log Collection Automation
**Current**: Logs scattered
**Enhancement**: Centralized log collection

**Implementation**:
```bash
./scripts/collect-logs.sh
```

**Actions**:
- Collect all container logs
- Collect application logs
- Create timestamped log archive
- Generate log summary

### Low Priority

#### 8. Performance Metrics Collection
**Current**: No performance tracking
**Enhancement**: Basic timing metrics

**Metrics**:
- Export duration
- Export file size
- Import duration
- Validation duration
- Total migration time

**Implementation**:
```bash
# In each step script
START=$(date +%s)
# ... perform step ...
END=$(date +%s)
DURATION=$((END - START))
echo "Duration: ${DURATION}s" >> metrics.txt
```

#### 9. Docker Resource Monitoring
**Current**: No resource monitoring
**Enhancement**: Resource usage tracking

**Metrics**:
- Container CPU usage
- Container memory usage
- Disk I/O
- Network I/O

**Implementation**:
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" >> logs/resource-usage.log
```

---

## Recommended Changes

### 1. Test Data Distribution

**Current Proposal**:
- Avro: 10 artifacts
- Protobuf: 5 artifacts
- JSON Schema: 5 artifacts
- OpenAPI: 3 artifacts
- AsyncAPI: 2 artifacts

**Recommendation**: ✅ **Approved as-is**

This distribution is appropriate for scenario 1. It provides good coverage without being overwhelming.

### 2. Version Count Per Artifact

**Current Proposal**: 3-5 versions per artifact

**Recommendation**: **Make it more specific**

**Suggested Distribution**:
- 50% of artifacts: 3 versions (testing typical use case)
- 30% of artifacts: 5 versions (testing moderate versioning)
- 20% of artifacts: 10 versions (testing heavy versioning)

**Rationale**: Tests various versioning patterns users might have.

### 3. Artifact References

**Current Proposal**: ~5 artifacts with references

**Recommendation**: **More explicit reference patterns**

**Suggested Patterns**:
1. Protobuf with single import
2. Protobuf with multiple imports
3. JSON Schema with single $ref
4. JSON Schema with nested $refs
5. Circular references (if supported)

**Rationale**: Tests various reference scenarios users encounter.

### 4. Nginx Configuration

**Current Proposal**: Single upstream with config file swap

**Recommendation**: **Consider blue-green upstream configuration**

**Alternative Approach**:
```nginx
upstream registry_blue {
    server apicurio-registry-v2:8080;
}

upstream registry_green {
    server apicurio-registry-v3:8080;
}

upstream registry_backend {
    server apicurio-registry-v2:8080;  # Active upstream
}
```

**Benefits**:
- Easier to switch between versions
- Can have both running simultaneously
- Supports quick rollback

**Rationale**: More realistic production pattern.

---

## Implementation Recommendations

### Phase 1: Core Components (Week 1)
1. ✅ Docker Compose configurations
2. ✅ Nginx configuration
3. ✅ Helper scripts (wait-for-health, cleanup)

### Phase 2: Java Clients (Week 1-2)
1. ✅ Artifact Creator (v2 client)
2. ✅ Artifact Validator (v2 client)
3. ✅ Artifact Validator (v3 client)

### Phase 3: Automation Scripts (Week 2)
1. ✅ Step-by-step execution scripts
2. ✅ Master orchestration script
3. ✅ Report generation script

### Phase 4: Testing & Refinement (Week 3)
1. ✅ Run full scenario multiple times
2. ✅ Fix issues
3. ✅ Optimize timing
4. ✅ Improve error handling

---

## Risk Assessment

### Low Risk
- ✅ Docker infrastructure setup
- ✅ Basic artifact creation
- ✅ Export/import process
- ✅ Simple validation

### Medium Risk
- ⚠️ Artifact references (complex to validate)
- ⚠️ Content hash preservation (requires careful validation)
- ⚠️ Version metadata (easy to miss edge cases)

### Mitigation Strategies

**For Artifact References**:
- Create comprehensive test data with known reference patterns
- Validate each reference individually
- Test both inbound and outbound references

**For Content Hash Preservation**:
- Store expected hashes in creation summary
- Compare hashes before and after migration
- Test hash-based retrieval

**For Version Metadata**:
- Create detailed metadata inventory
- Compare metadata field-by-field
- Test special characters and edge cases

---

## Future Enhancements (Beyond Scenario 1)

### Scenario 2: Authentication & Authorization
- Add Keycloak container
- Test RBAC migration
- Test owner-only authorization
- Validate token-based access

### Scenario 3: Kafka SerDes
- Add Kafka container
- Test Avro SerDes
- Test Protobuf SerDes
- Test JSON Schema SerDes
- Validate schema evolution

### Scenario 4: KafkaSQL Storage
- Use KafkaSQL for v2
- Migrate to KafkaSQL for v3
- Test snapshot functionality
- Validate replication

### Scenario 5: Performance Testing
- Large dataset (10,000+ artifacts)
- Concurrent client operations
- Import performance testing
- Query performance comparison

### Scenario 6: Failure & Recovery
- Test import failures
- Test partial imports
- Test rollback procedures
- Test data corruption handling

---

## Questions for Clarification

### 1. Artifact Type Distribution
**Question**: Should we include less common types like WSDL or XSD?

**Recommendation**: Not for scenario 1. Keep it focused on commonly used types (Avro, Protobuf, JSON,
OpenAPI, AsyncAPI).

### 2. UI Testing
**Question**: Should we include UI testing in scenario 1?

**Recommendation**: No. UI testing should be scenario 8 or later. Keep scenario 1 focused on API and
data migration.

### 3. Version Naming
**Question**: Should we test SemVer version naming vs integer versions?

**Recommendation**: Yes! Mix both:
- 50% use integer versions (1, 2, 3, ...)
- 50% use SemVer (1.0.0, 1.1.0, 2.0.0, ...)

This tests the new SemVer support in 3.1.x.

### 4. Group Structure
**Question**: Should we use multiple groups or just "default"?

**Recommendation**: Use multiple groups:
- `default` - 10 artifacts
- `com.example.avro` - 5 artifacts
- `com.example.protobuf` - 5 artifacts
- `com.example.rest` - 5 artifacts

This tests group migration and group metadata.

### 5. Error Scenarios
**Question**: Should we test error conditions in scenario 1?

**Recommendation**: Only basic error handling (import to non-empty registry). Save comprehensive error
testing for scenario 6.

---

## Success Metrics

### Quantitative Metrics
- ✅ 100% artifact migration success rate
- ✅ 100% version migration success rate
- ✅ 100% metadata preservation rate
- ✅ 0 data loss incidents
- ✅ < 5 minute total migration time
- ✅ < 10% performance degradation for queries

### Qualitative Metrics
- ✅ Clear, understandable test output
- ✅ Easy to diagnose failures
- ✅ Reusable components for other scenarios
- ✅ Well-documented process
- ✅ Automated end-to-end

---

## Conclusion

The proposed test scenario is **excellent** and provides a solid foundation for migration testing.

**Recommended Next Steps**:

1. ✅ **Approve the test plan** as documented
2. ✅ **Implement Phase 1** (Docker infrastructure)
3. ✅ **Implement Phase 2** (Java clients)
4. ✅ **Implement Phase 3** (Automation scripts)
5. ✅ **Execute and refine** the scenario
6. ✅ **Document lessons learned** for subsequent scenarios

**Estimated Effort**: 2-3 weeks for full implementation and testing

**Priority**: HIGH - This is the foundation for all subsequent migration testing scenarios

---

**Evaluator**: Migration Testing Analysis
**Date**: 2025-11-12
**Status**: APPROVED WITH ENHANCEMENTS
