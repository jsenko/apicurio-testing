# Apicurio Registry System Tests Analysis

**Date:** 2025-10-22
**Purpose:** Catalog all system tests from `apicurio-registry-system-tests` and identify which tests are already covered by existing integration tests.

---

## Table of Contents

1. [Overview](#overview)
2. [API Tests - CRUD Operations](#1-api-tests---crud-operations)
3. [Authentication & Authorization Tests](#2-authentication--authorization-tests)
4. [Persistence Tests](#3-persistence-tests)
5. [Configuration Tests](#4-configuration-tests)
6. [Deployment Tests](#5-deployment-tests)
7. [OAuth Kafka Tests](#6-oauth-kafka-tests)
8. [Security/Rapidast Tests](#7-securityrapidast-tests)
9. [Upgrade Tests](#8-upgrade-tests)
10. [Summary & Recommendations](#summary--recommendations)

---

## Overview

### System Tests Characteristics
- **Total Test Files:** ~55 test classes
- **Location:** `apicurio-registry-system-tests/src/test/java`
- **Framework:** JUnit 5 with custom Kubernetes infrastructure
- **Client:** Custom `ApicurioRegistryApiClient` (not official SDK)
- **Deployment:** Kubernetes operators, custom resources
- **Focus:** End-to-end system scenarios, deployment configurations

### Integration Tests Characteristics
- **Total Test Files:** 22 test classes
- **Location:** `apicurio-registry/integration-tests/src/test/java`
- **Framework:** JUnit 5 with Quarkus integration testing
- **Client:** Official Registry V3 SDK (`RegistryClient`)
- **Deployment:** Quarkus test deployment (in-memory, SQL, KafkaSQL)
- **Focus:** API functionality, business logic

---

## 1. API Tests - CRUD Operations

**Test Class:** [`APITests.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/api/APITests.java) (and subclasses)
**Features Package:** [`api.features.CreateReadUpdateDelete`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/api/features/CreateReadUpdateDelete.java)

### Test Matrix

The system tests create a comprehensive matrix testing **every artifact type** against **every persistence backend** and **every authentication mode**.

#### Artifact Types Tested (10 types)
1. AVRO
2. Protobuf
3. JSON Schema
4. OpenAPI
5. AsyncAPI
6. GraphQL
7. Kafka Connect (Kconnect)
8. WSDL
9. XSD
10. XML

#### Persistence Backends
- **SQL** (PostgreSQL)
- **KafkaSQL** with variants:
  - No Auth
  - TLS
  - SCRAM

#### Authentication Modes
- No Authentication (NoIAM)
- Keycloak (OAuth2)

### Complete Test List

| Test Name | Artifact Type | Persistence | Kafka Auth | Registry Auth | Already Covered? |
|-----------|--------------|-------------|------------|---------------|------------------|
| `testRegistrySqlNoIAMCreateReadUpdateDeleteAvro` | AVRO | SQL | N/A | None | ✅ YES - `ArtifactsIT` |
| `testRegistrySqlKeycloakCreateReadUpdateDeleteAvro` | AVRO | SQL | N/A | Keycloak | ✅ YES - `ArtifactsIT` |
| `testRegistryKafkasqlNoAuthNoIAMCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | NoAuth | None | ✅ YES - Basic CRUD tested |
| `testRegistryKafkasqlNoAuthKeycloakCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | NoAuth | Keycloak | ✅ YES - Basic CRUD tested |
| `testRegistryKafkasqlTLSNoIAMCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | TLS | None | ❌ NO - Storage variant |
| `testRegistryKafkasqlTLSKeycloakCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | TLS | Keycloak | ❌ NO - Storage variant |
| `testRegistryKafkasqlSCRAMNoIAMCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | SCRAM | None | ❌ NO - Storage variant |
| `testRegistryKafkasqlSCRAMKeycloakCreateReadUpdateDeleteAvro` | AVRO | KafkaSQL | SCRAM | Keycloak | ❌ NO - Storage variant |

**Note:** The above pattern repeats for all 10 artifact types, resulting in **90 total permutation tests**.

### What Each Test Does

```
// Simplified test flow
1. Deploy Registry with specified persistence and auth configuration
2. Create artifact with specific type
3. List artifacts and verify creation
4. Read artifact content and verify
5. Update artifact content
6. Read again and verify update
7. Delete artifact
8. Verify deletion
```

### Coverage Analysis

| Aspect | System Tests | Integration Tests | Gap |
|--------|--------------|-------------------|-----|
| **CRUD Operations** | ✅ All types | ✅ Core types (Avro, Protobuf, JSON) | Minor - some artifact types |
| **Artifact Types** | ✅ All 10 types | ✅ ~6 types tested | `AllArtifactTypesIT` covers most |
| **SQL Persistence** | ✅ Tested | ✅ Tested | None |
| **KafkaSQL Persistence** | ✅ All variants | ✅ Basic KafkaSQL | TLS/SCRAM variants not tested |
| **OAuth2 Auth** | ✅ Tested | ✅ Tested | None |

**Conclusion:** ✅ **Core CRUD functionality is well covered.** The 90 system tests primarily test **deployment configuration permutations** rather than unique functional scenarios.

---

## 2. Authentication & Authorization Tests

**Test Class:** [`AuthTests.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java) (and subclasses)
**Features Package:** `auth.features.*`

### 2.1 Anonymous Read Access

**Test:** [`testRegistrySql*AnonymousReadAccess`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L148-L158)
**Feature Class:** [`AnonymousReadAccess.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/AnonymousReadAccess.java)

#### What It Tests
- Unauthenticated users can **read** artifacts
- Unauthenticated users **cannot create/update/delete** artifacts
- Configuration: `apicurio.auth.anonymous-read-access.enabled=true`

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Registry Auth | Coverage |
|-----------|-------------|------------|---------------|----------|
| `testRegistrySqlNoIAMAnonymousReadAccess` | SQL | N/A | None (anonymous) | ❌ NOT COVERED |
| `testRegistrySqlKeycloakAnonymousReadAccess` | SQL | N/A | Keycloak | ❌ NOT COVERED |
| `testRegistryKafkasql*AnonymousReadAccess` (6 variants) | KafkaSQL | Various | Various | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No existing test for anonymous read-only access mode.

---

### 2.2 Basic Authentication

**Test:** [`testRegistrySql*BasicAuthentication`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L164-L166)
**Feature Class:** [`BasicAuthentication.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/BasicAuthentication.java)

#### What It Tests
- HTTP Basic Authentication (username/password)
- Users authenticated via Keycloak can access registry
- Credentials sent via `Authorization: Basic` header

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakBasicAuthentication` | SQL | N/A | ❓ PARTIAL |
| `testRegistryKafkasql*BasicAuthentication` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❓ PARTIAL |

#### Integration Test Coverage
**❓ PARTIAL** - `SimpleAuthIT` tests OAuth2/OIDC but not HTTP Basic Auth specifically.

---

### 2.3 Authenticated Reads

**Test:** [`testRegistrySql*AuthenticatedReads`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L170-L172)
**Feature Class:** [`AuthenticatedReads.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/AuthenticatedReads.java)

#### What It Tests
- Only authenticated users can **read** artifacts
- Anonymous access is completely blocked
- Configuration: `apicurio.auth.authenticated-read-access.enabled=true`

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakAuthenticatedReads` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*AuthenticatedReads` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No existing test for authenticated-read-only mode.

---

### 2.4 Artifact Owner-Only Authorization

**Test:** [`testRegistrySql*ArtifactOwnerOnlyAuthorization`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L176-L178)
**Feature Class:** [`ArtifactOwnerOnlyAuthorization.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/ArtifactOwnerOnlyAuthorization.java)

#### What It Tests
- Users can only modify artifacts **they created**
- Other users can read but not modify
- Tests ownership tracking at artifact level
- Configuration: `apicurio.auth.owner-only-authorization=true`

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakArtifactOwnerOnlyAuthorization` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*ArtifactOwnerOnlyAuthorization` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No existing test for artifact-level ownership authorization.

---

### 2.5 Artifact Group Owner-Only Authorization

**Test:** [`testRegistrySql*ArtifactGroupOwnerOnlyAuthorization`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L182-L184)
**Feature Class:** [`ArtifactGroupOwnerOnlyAuthorization.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/ArtifactGroupOwnerOnlyAuthorization.java)

#### What It Tests
- Users can only modify artifacts in groups **they created**
- Other users can read but not modify group artifacts
- Tests ownership tracking at group level
- Configuration: `apicurio.auth.owner-only-authorization=true` + `apicurio.auth.owner-only-authorization.limit-group-access=true`

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakArtifactGroupOwnerOnlyAuthorization` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*ArtifactGroupOwnerOnlyAuthorization` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No existing test for group-level ownership authorization.

---

### 2.6 Role-Based Authorization (Token)

**Test:** [`testRegistrySql*RoleBasedAuthorizationToken`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L188-L190)
**Feature Class:** [`RoleBasedAuthorizationToken.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/RoleBasedAuthorizationToken.java)

#### What It Tests
- **Admin Role:** Full access (create, read, update, delete, manage rules, manage roles)
- **Developer Role:** Can create/read/update/delete artifacts and artifact rules, but NOT global rules or role management
- **Read-Only Role:** Can only read artifacts and rules
- Roles extracted from OAuth2 token claims
- Configuration: `apicurio.auth.role-based-authorization=true`

#### Detailed Permissions Tested

| Operation | Admin | Developer | Read-Only |
|-----------|-------|-----------|-----------|
| List artifacts | ✅ | ✅ | ✅ |
| Create artifact | ✅ | ✅ | ❌ |
| Read artifact | ✅ | ✅ | ✅ |
| Update artifact | ✅ | ✅ | ❌ |
| Delete artifact | ✅ | ✅ | ❌ |
| Create artifact rule | ✅ | ✅ | ❌ |
| Update artifact rule | ✅ | ✅ | ❌ |
| Delete artifact rule | ✅ | ✅ | ❌ |
| Create global rule | ✅ | ❌ | ❌ |
| Update global rule | ✅ | ❌ | ❌ |
| Delete global rule | ✅ | ❌ | ❌ |
| Manage role mappings | ✅ | ❌ | ❌ |

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakRoleBasedAuthorizationToken` | SQL | N/A | ✅ YES |
| `testRegistryKafkasql*RoleBasedAuthorizationToken` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ✅ YES |

#### Integration Test Coverage
**✅ WELL COVERED** - `SimpleAuthIT` has comprehensive tests:
- `testReadOnly()` - Tests read-only role
- `testDevRole()` - Tests developer role
- `testAdminRole()` - Tests admin role

---

### 2.7 Role-Based Authorization (Application)

**Test:** [`testRegistrySql*RoleBasedAuthorizationApplication`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L194-L196)
**Feature Class:** [`RoleBasedAuthorizationApplication.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/RoleBasedAuthorizationApplication.java)

#### What It Tests
- Same as token-based RBAC but using **application-type OAuth clients**
- Tests service accounts vs user accounts
- Client credentials flow vs authorization code flow

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakRoleBasedAuthorizationApplication` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*RoleBasedAuthorizationApplication` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No specific tests for application-type OAuth clients vs user clients.

---

### 2.8 Role-Based Authorization (Custom Role Names)

**Test:** [`testRegistrySql*RoleBasedAuthorizationRoleNames`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L200-L202)
**Feature Class:** [`RoleBasedAuthorizationRoleNames.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/RoleBasedAuthorizationRoleNames.java)

#### What It Tests
- Custom role names instead of default `sr-admin`, `sr-developer`, `sr-readonly`
- Configuration: `apicurio.auth.role-based-authorization.roles.admin=custom-admin-role`
- Tests that role mapping works with non-default role names

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakRoleBasedAuthorizationRoleNames` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*RoleBasedAuthorizationRoleNames` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No tests for custom role name configuration.

---

### 2.9 Role-Based Authorization (Admin Override via Role)

**Test:** [`testRegistrySql*RoleBasedAuthorizationAdminOverrideRole`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L206-L209)
**Feature Class:** [`RoleBasedAuthorizationAdminOverrideRole.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/RoleBasedAuthorizationAdminOverrideRole.java)

#### What It Tests
- Specific role can override RBAC and act as super-admin
- Configuration: `apicurio.auth.admin-override.role=super-admin`
- Tests that users with override role have full access regardless of other permissions

#### Test Scenarios
| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakRoleBasedAuthorizationAdminOverrideRole` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*RoleBasedAuthorizationAdminOverrideRole` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No tests for admin override via role.

---

### 2.10 Role-Based Authorization (Admin Override via Claim)

**Test:** [`testRegistrySql*RoleBasedAuthorizationAdminOverrideClaim`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/AuthTests.java#L214-L228)
**Feature Class:** [`RoleBasedAuthorizationAdminOverrideClaim.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/auth/features/RoleBasedAuthorizationAdminOverrideClaim.java)

#### What It Tests
- JWT claim value can grant admin override
- Configuration: `apicurio.auth.admin-override.claim=org-admin` + `apicurio.auth.admin-override.claim-value=true`
- **Parameterized test** with multiple claim configurations from CSV file

#### Test Scenarios (Parameterized)
Uses data from `/adminOverrideClaimData.csv`:
- Different claim names (`org-admin`, `is-superuser`, etc.)
- Different claim values (`true`, `admin`, custom values)
- Tests that matching claims grant full admin access

| Test Name | Persistence | Kafka Auth | Coverage |
|-----------|-------------|------------|----------|
| `testRegistrySqlKeycloakRoleBasedAuthorizationAdminOverrideClaim` | SQL | N/A | ❌ NOT COVERED |
| `testRegistrySqlKeycloakRoleBasedAuthorizationAdminOverrideClaimExtended` | SQL | N/A | ❌ NOT COVERED |
| `testRegistryKafkasql*RoleBasedAuthorizationAdminOverrideClaim` (3 variants) | KafkaSQL | NoAuth/TLS/SCRAM | ❌ NOT COVERED |

#### Integration Test Coverage
**❌ NOT COVERED** - No tests for admin override via JWT claims.

---

### Authentication Tests Summary

| Feature | System Tests | Integration Tests | Priority to Convert |
|---------|--------------|-------------------|---------------------|
| Anonymous Read Access | ✅ 8 tests | ❌ None | 🔴 HIGH |
| Basic Authentication | ✅ 4 tests | ❓ Partial (OAuth only) | 🟡 MEDIUM |
| Authenticated Reads | ✅ 4 tests | ❌ None | 🔴 HIGH |
| Artifact Owner-Only | ✅ 4 tests | ❌ None | 🔴 HIGH |
| Group Owner-Only | ✅ 4 tests | ❌ None | 🔴 HIGH |
| RBAC Token | ✅ 4 tests | ✅ Well covered | 🟢 LOW |
| RBAC Application | ✅ 4 tests | ❌ None | 🟡 MEDIUM |
| RBAC Custom Roles | ✅ 4 tests | ❌ None | 🟡 MEDIUM |
| Admin Override (Role) | ✅ 4 tests | ❌ None | 🟢 LOW |
| Admin Override (Claim) | ✅ ~12 tests | ❌ None | 🟢 LOW |

**Total Auth System Tests:** ~52 tests
**Well Covered:** 4 tests (RBAC Token)
**High Priority Gaps:** 20 tests (Anonymous, Authenticated Reads, Owner-Only)

---

## 3. Persistence Tests

**Test Class:** [`PersistenceTests.java`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/persistence/PersistenceTests.java)
**Features Package:** [`persistence.features.CreateReadRestartReadDelete`](https://github.com/Apicurio/apicurio-registry-system-tests/blob/main/src/test/java/io/apicurio/registry/systemtests/persistence/features/CreateReadRestartReadDelete.java)

### What It Tests

Tests that data **persists across registry pod restarts**.

#### Test Flow
```
1. Create artifact
2. Read and verify artifact
3. Restart registry pod (by setting environment variable)
4. Wait for pod to restart
5. Read artifact again
6. Verify artifact still exists with correct content
7. Delete artifact
```

### Test Scenarios

| Test Name | Persistence | Kafka Auth | Registry Auth | Coverage |
|-----------|-------------|------------|---------------|----------|
| `testRegistrySqlNoIAMCreateReadRestartReadDelete` | SQL | N/A | None | ❌ NOT COVERED |
| `testRegistrySqlKeycloakCreateReadRestartReadDelete` | SQL | N/A | Keycloak | ❌ NOT COVERED |
| `testRegistryKafkasqlNoAuthNoIAMCreateReadRestartReadDelete` | KafkaSQL | NoAuth | None | ❌ NOT COVERED |
| `testRegistryKafkasqlNoAuthKeycloakCreateReadRestartReadDelete` | KafkaSQL | NoAuth | Keycloak | ❌ NOT COVERED |
| `testRegistryKafkasqlTLSNoIAMCreateReadRestartReadDelete` | KafkaSQL | TLS | None | ❌ NOT COVERED |
| `testRegistryKafkasqlTLSKeycloakCreateReadRestartReadDelete` | KafkaSQL | TLS | Keycloak | ❌ NOT COVERED |
| `testRegistryKafkasqlSCRAMNoIAMCreateReadRestartReadDelete` | KafkaSQL | SCRAM | None | ❌ NOT COVERED |
| `testRegistryKafkasqlSCRAMKeycloakCreateReadRestartReadDelete` | KafkaSQL | SCRAM | Keycloak | ❌ NOT COVERED |

### Integration Test Coverage

**❌ NOT COVERED** - Requires ability to restart the registry application/container.

**Note:** This is primarily a **deployment/infrastructure test** rather than a functional test. Integration tests don't have pod restart capability.

**Convertibility:** 🟡 **MEDIUM** - Would require test container restart support.

---

## 4. Configuration Tests

**Test Classes:**
- `ConfigTests.java`
- `OLMConfigTests.java`
- `BundleConfigTests.java`
- `OLMClusterWideConfigTests.java`
- `OLMNamespacedConfigTests.java`

### Purpose

These tests verify **Kubernetes operator configuration** and custom resource management:
- Environment variable configuration via CRD
- Config map mounting
- Secret mounting
- Resource limits and requests
- Replica configuration
- Ingress/Route configuration

### Convertibility

**❌ NOT APPLICABLE** - These are Kubernetes operator tests, not functional API tests.

**Recommendation:** Do not convert - these require Kubernetes infrastructure.

---

## 5. Deployment Tests

**Test Classes:**
- `DeployTests.java`
- `OLMDeployTests.java`
- `BundleDeployTests.java`
- `OLMClusterWideDeployTests.java`
- `OLMNamespacedDeployTests.java`

### Purpose

These tests verify **Kubernetes/OpenShift operator deployment**:
- Operator installation
- Custom resource creation
- Pod deployment
- Service creation
- Route/Ingress creation
- Operator upgrades
- Resource cleanup

### Convertibility

**❌ NOT APPLICABLE** - These are infrastructure deployment tests.

**Recommendation:** Do not convert - these require Kubernetes operator infrastructure.

---

## 6. OAuth Kafka Tests

**Test Classes:**
- `OAuthKafkaTests.java`
- `OLMOAuthKafkaTests.java`
- `BundleOAuthKafkaTests.java`
- `OLMClusterWideOAuthKafkaTests.java`
- `OLMNamespacedOAuthKafkaTests.java`

### Purpose

These tests verify **KafkaSQL storage with OAuth authentication to Kafka**:
- Registry authenticates to Kafka using OAuth2
- Tests client credentials flow
- Tests token refresh
- Tests Kafka connection with OAuth

### Convertibility

**❓ POSSIBLY TESTABLE** - Would require:
1. Kafka testcontainer with OAuth support
2. OAuth provider (Keycloak) testcontainer
3. Complex test setup

**Recommendation:** 🟡 **LOW PRIORITY** - Very specialized scenario, complex setup required.

---

## 7. Security/Rapidast Tests

**Test Classes:**
- `RapidastTests.java`
- `OLMRapidastTests.java`
- `BundleRapidastTests.java`
- `StaticRapidastTests.java`
- `OLMClusterWideRapidastTests.java`
- `OLMNamespacedRapidastTests.java`

### Purpose

These tests run **security scanning** using the Rapidast tool:
- OWASP ZAP scanning
- API security testing
- Vulnerability detection
- Security compliance checks

### Convertibility

**❌ NOT APPLICABLE** - These are security scanning tests, not functional tests.

**Recommendation:** Do not convert - these are security tooling tests.

---

## 8. Upgrade Tests

**Test Class:** `OLMUpgradeTests.java`

### Purpose

Tests **version upgrades** via Kubernetes operator:
- Upgrade from version N to version N+1
- Data migration during upgrade
- Backward compatibility
- Rollback scenarios

### Convertibility

**❌ NOT APPLICABLE** - These are operator upgrade tests.

**Recommendation:** Do not convert - these require operator infrastructure and multiple registry versions.

---

## Summary & Recommendations

### Test Categories Overview

| Category | System Tests | Applicable to Integration Tests? | Value if Converted |
|----------|--------------|-----------------------------------|-------------------|
| **API/CRUD** | ~90 tests | ✅ YES | 🟢 LOW - Already covered |
| **Authentication** | ~52 tests | ✅ YES | 🔴 HIGH - Major gaps |
| **Persistence** | ~8 tests | ❓ MAYBE | 🟡 MEDIUM - Needs infrastructure |
| **Configuration** | ~15 tests | ❌ NO | N/A - Operator only |
| **Deployment** | ~15 tests | ❌ NO | N/A - Operator only |
| **OAuth Kafka** | ~15 tests | ❓ MAYBE | 🟡 LOW - Complex setup |
| **Security/Rapidast** | ~18 tests | ❌ NO | N/A - Security scanning |
| **Upgrade** | ~5 tests | ❌ NO | N/A - Operator only |

### High-Priority Tests to Convert

#### 🔴 Tier 1: Critical Gaps (High Business Value)

1. **Anonymous Read Access** (`AnonymousReadAccess.java`)
   - **Why:** Important public registry use case
   - **Effort:** Low
   - **Impact:** High
   - **Tests:** 8 variants

2. **Artifact Owner-Only Authorization** (`ArtifactOwnerOnlyAuthorization.java`)
   - **Why:** Important multi-tenant feature
   - **Effort:** Medium
   - **Impact:** High
   - **Tests:** 4 variants

3. **Artifact Group Owner-Only Authorization** (`ArtifactGroupOwnerOnlyAuthorization.java`)
   - **Why:** Group-level access control
   - **Effort:** Medium
   - **Impact:** High
   - **Tests:** 4 variants

4. **Authenticated Reads** (`AuthenticatedReads.java`)
   - **Why:** Private registry use case
   - **Effort:** Low
   - **Impact:** Medium-High
   - **Tests:** 4 variants

#### 🟡 Tier 2: Nice to Have

5. **Basic Authentication** (`BasicAuthentication.java`)
   - **Why:** Alternative to OAuth2
   - **Effort:** Low
   - **Impact:** Medium
   - **Tests:** 4 variants

6. **RBAC Application** (`RoleBasedAuthorizationApplication.java`)
   - **Why:** Service account scenarios
   - **Effort:** Medium
   - **Impact:** Medium
   - **Tests:** 4 variants

7. **Persistence After Restart** (`CreateReadRestartReadDelete.java`)
   - **Why:** Verify data durability
   - **Effort:** High (needs container restart)
   - **Impact:** Medium
   - **Tests:** 8 variants

#### 🟢 Tier 3: Low Priority

8. **RBAC Custom Role Names** (`RoleBasedAuthorizationRoleNames.java`)
   - **Why:** Configuration flexibility
   - **Effort:** Low
   - **Impact:** Low
   - **Tests:** 4 variants

9. **Admin Override Tests** (`RoleBasedAuthorizationAdminOverride*.java`)
   - **Why:** Specialized admin scenarios
   - **Effort:** Medium
   - **Impact:** Low
   - **Tests:** ~16 variants

### Recommended Conversion Plan

#### Phase 1: Core Authentication (Sprint 1)
- ✅ Anonymous Read Access
- ✅ Authenticated Reads
- ✅ Basic Authentication

**Estimated Effort:** 3-5 days
**Value:** Fills major authentication gaps

#### Phase 2: Authorization (Sprint 2)
- ✅ Artifact Owner-Only Authorization
- ✅ Artifact Group Owner-Only Authorization

**Estimated Effort:** 5-7 days
**Value:** Multi-tenant authorization features

#### Phase 3: Advanced (Future)
- ❓ RBAC Application
- ❓ Persistence After Restart
- ❓ Custom Role Names

**Estimated Effort:** 5-10 days
**Value:** Nice-to-have features

### Tests NOT Worth Converting

| Category | Reason | Count |
|----------|--------|-------|
| Configuration Tests | Requires K8s operator | ~15 |
| Deployment Tests | Requires K8s operator | ~15 |
| Rapidast Tests | Security scanning tool | ~18 |
| Upgrade Tests | Operator version testing | ~5 |
| OAuth Kafka Tests | Complex setup, low ROI | ~15 |
| CRUD Permutations | Already functionally covered | ~60 |

**Total Tests Not Worth Converting:** ~128 tests

### Final Statistics

- **Total System Tests:** ~218 tests
- **Worth Converting:** ~36 tests (17%)
- **High Priority:** ~20 tests (9%)
- **Not Applicable:** ~128 tests (59%)
- **Already Covered:** ~54 tests (25%)

---

## Appendix: Key Differences Between Test Suites

### System Tests
- ✅ Kubernetes deployment testing
- ✅ Operator configuration testing
- ✅ Multi-persistence combinations
- ✅ Infrastructure-level concerns
- ❌ Uses custom HTTP client (not SDK)
- ❌ Static utility methods (not typical JUnit)

### Integration Tests
- ✅ Uses official Registry SDK
- ✅ Proper JUnit 5 structure
- ✅ Quarkus test deployment
- ✅ Functional API testing
- ❌ No Kubernetes deployment
- ❌ Limited storage permutations

### Conversion Strategy

When converting a system test to an integration test:

1. **Change Test Structure**
   - FROM: Static methods in "features" classes
   - TO: JUnit `@Test` methods extending `ApicurioRegistryBaseIT`

2. **Replace Client**
   - FROM: Custom `ApicurioRegistryApiClient`
   - TO: Official `RegistryClient` from SDK

3. **Simplify Deployment**
   - FROM: Kubernetes custom resources, operators
   - TO: Quarkus test deployment (handled by base class)

4. **Update Authentication**
   - FROM: Manual token management with `KeycloakUtils`
   - TO: SDK-based OIDC authentication

5. **Adjust Assertions**
   - FROM: Custom client methods returning booleans/nulls
   - TO: SDK methods with proper exception handling

---

**End of Analysis**
