# Apicurio Registry Migration Analysis: Version 2.6.x to 3.1.x

**Date**: 2025-11-12
**Author**: Migration Testing Analysis
**Purpose**: Comprehensive analysis of Apicurio Registry migration from version 2.6.x to 3.1.x

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Apicurio Registry 2.6.x Analysis](#apicurio-registry-26x-analysis)
3. [Apicurio Registry 3.1.x Analysis](#apicurio-registry-31x-analysis)
4. [Migration Guide Summary](#migration-guide-summary)
5. [Migration Testing Recommendations](#migration-testing-recommendations)
6. [References](#references)

---

## Executive Summary

### Critical Breaking Changes

Apicurio Registry 3.1.x introduces **breaking changes** that prevent automatic upgrade from version 2.6.x. A
manual migration process is required.

**Key Breaking Changes:**
- Configuration namespace change: `registry.*` → `apicurio.*`
- New REST API v3 introduced (v2 API deprecated but maintained for compatibility)
- Client libraries replaced with Kiota-generated SDKs
- Data model changes: artifacts can now be empty, groups have first-class metadata
- KafkaSQL storage completely rewritten

**Migration Approach:**
1. Export data from 2.6.x deployment
2. Deploy new 3.1.x instance with updated configuration
3. Import data into 3.1.x deployment
4. Update client applications
5. Validate and test thoroughly

---

## Apicurio Registry 2.6.x Analysis

### Deployment Configuration Options

#### Repository Information
- **Branch**: 2.6.x
- **Repository**: git@github.com:Apicurio/apicurio-registry.git
- **Local Path**: `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6`

#### Deployment Types Supported

##### OpenShift Templates
Location: `distro/openshift-template/`

Available templates:
- `apicurio-registry-template-sql.yml` - PostgreSQL-backed deployment
- `apicurio-registry-template-kafkasql.yml` - Kafka+SQL hybrid storage
- `apicurio-registry-template-mem.yml` - In-memory storage (evaluation only)

**Template Features:**
- DeploymentConfig with ImageStream
- Service (NodePort on port 32222)
- Route with TLS edge termination
- Health probes: `/health/live` and `/health/ready`
- Configurable resource limits/requests

##### Docker / Docker Compose
Location: `distro/docker-compose/`

Available configurations:
- `compose-base-sql.yml` - PostgreSQL backend
- `compose-base-mssql.yml` - MS SQL Server backend
- `docker-compose.apicurio.yml` - Full stack with Keycloak authentication
- `compose-metrics.yml` - With Prometheus and Grafana monitoring

##### Docker Images
Location: `distro/docker/`

Available Dockerfiles:
- `Dockerfile.jvm` - In-memory (H2) storage
- `Dockerfile.sql.jvm` - PostgreSQL storage
- `Dockerfile.kafkasql.jvm` - Kafka+SQL storage
- `Dockerfile.mysql.jvm` - MySQL storage
- `Dockerfile.mssql.jvm` - MS SQL Server storage
- `Dockerfile.native` - Native compilation
- `Dockerfile.native-scratch` - Minimal native image

#### Storage Backend Options

##### 1. SQL-Based Storage (PostgreSQL - Default)

**Configuration:**
```properties
REGISTRY_DATASOURCE_URL=jdbc:postgresql://host:5432/database
REGISTRY_DATASOURCE_USERNAME=postgres
REGISTRY_DATASOURCE_PASSWORD=password
quarkus.datasource.db-kind=postgresql
```

**Connection Pool Settings:**
- Initial size: 20
- Min size: 20
- Max size: 100

##### 2. KafkaSQL Storage (Hybrid Kafka+SQL)

**Configuration:**
```properties
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
REGISTRY_DATASOURCE_URL=jdbc:h2:mem:registry_db
registry.kafkasql.topic=kafkasql-journal
registry.kafkasql.producer.client.id=${registry.id}-producer
registry.kafkasql.consumer.group.id=${registry.id}-${quarkus.uuid}
```

**Kafka Security:**
- SASL/OAUTHBEARER support
- SSL/TLS with truststore/keystore
- Protocol: `KAFKA_SECURITY_PROTOCOL`
- OAuth endpoint: `OAUTH_TOKEN_ENDPOINT_URI`

##### 3. MySQL Storage

**Configuration:**
```properties
REGISTRY_DATASOURCE_URL=jdbc:mysql://host:3306/database
REGISTRY_DATASOURCE_USERNAME=mysql
REGISTRY_DATASOURCE_PASSWORD=mysql
quarkus.datasource.db-kind=mysql
```

##### 4. MS SQL Server Storage

**Configuration:**
```properties
REGISTRY_DATASOURCE_URL=jdbc:sqlserver://host;trustServerCertificate=true
REGISTRY_DATASOURCE_USERNAME=sa
REGISTRY_DATASOURCE_PASSWORD=password
quarkus.datasource.db-kind=mssql
```

##### 5. In-Memory Storage (H2)

**Configuration:**
```properties
REGISTRY_DATASOURCE_URL=jdbc:h2:mem:registry_db
```

**Note**: For evaluation/testing only - data lost on restart

#### Authentication & Authorization Configuration

##### Core Authentication Settings
```properties
AUTH_ENABLED=true/false
REGISTRY_AUTH_ENABLED=true/false
KEYCLOAK_URL=http://localhost:8090/auth
KEYCLOAK_REALM=apicurio-local
KEYCLOAK_API_CLIENT_ID=registry-api
KEYCLOAK_API_CLIENT_SECRET=<secret>
REGISTRY_AUTH_URL_CONFIGURED=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}
TOKEN_ENDPOINT=${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token
```

##### Authorization Modes

**Role-Based Access Control (RBAC):**
```properties
REGISTRY_AUTH_RBAC_ENABLED=true/false
REGISTRY_AUTH_ROLE_SOURCE=token|header|application
REGISTRY_AUTH_ROLES_ADMIN=sr-admin
REGISTRY_AUTH_ROLES_DEVELOPER=sr-developer
REGISTRY_AUTH_ROLES_READONLY=sr-readonly
```

**Owner-Based Access Control (OBAC):**
```properties
REGISTRY_AUTH_OBAC_ENABLED=true/false
REGISTRY_AUTH_OBAC_LIMIT_GROUP_ACCESS=true/false
```

**Anonymous/Authenticated Read Access:**
```properties
REGISTRY_AUTH_ANONYMOUS_READS_ENABLED=true/false
REGISTRY_AUTH_AUTHENTICATED_READS_ENABLED=true/false
```

##### Basic Auth with Client Credentials
```properties
CLIENT_CREDENTIALS_BASIC_AUTH_ENABLED=true/false
CLIENT_CREDENTIALS_BASIC_CACHE_EXPIRATION=10
registry.auth.basic-auth.scope=<scope>
```

##### Admin Override
```properties
REGISTRY_AUTH_ADMIN_OVERRIDE_ENABLED=true/false
REGISTRY_AUTH_ADMIN_OVERRIDE_FROM=token
REGISTRY_AUTH_ADMIN_OVERRIDE_TYPE=role
REGISTRY_AUTH_ADMIN_OVERRIDE_ROLE=sr-admin
REGISTRY_AUTH_ADMIN_OVERRIDE_CLAIM=org-admin
REGISTRY_AUTH_ADMIN_OVERRIDE_CLAIM_VALUE=true
```

##### UI Authentication (OIDC)
```properties
REGISTRY_UI_AUTH_TYPE=none|oidc|keycloak
REGISTRY_OIDC_UI_CLIENT_ID=default_client
REGISTRY_OIDC_UI_REDIRECT_URL=http://localhost:8080
REGISTRY_OIDC_UI_SCOPE=openid email profile
registry.ui.config.auth.oidc.token-type=access|id
```

#### API & Compatibility Configuration

##### Confluent Schema Registry Compatibility API
```properties
ENABLE_CCOMPAT_LEGACY_ID_MODE=true/false
ENABLE_CCOMPAT_CANONICAL_HASH_MODE=true/false
registry.ccompat.max-subjects=1000
registry.ccompat.group-concat.enabled=true/false
registry.ccompat.group-concat.separator=:
```

##### Disabled APIs
```properties
registry.disable.apis=/apis/ibmcompat/.*
```

#### Limits & Resource Constraints

```properties
registry.limits.config.max-artifacts=-1
registry.limits.config.max-versions-per-artifact=-1
registry.limits.config.max-total-schemas=-1
registry.limits.config.max-schema-size-bytes=-1
registry.limits.config.max-artifact-properties=-1
registry.limits.config.max-artifact-labels=-1
registry.limits.config.max-name-length=-1
registry.limits.config.max-description-length=-1
registry.limits.config.max-label-size=-1
registry.limits.config.max-property-key-size=-1
registry.limits.config.max-property-value-size=-1
registry.limits.config.max-requests-per-second=-1
```

#### Health & Monitoring

##### Liveness Probes
```properties
LIVENESS_ERROR_THRESHOLD=5
LIVENESS_COUNTER_RESET=30
LIVENESS_STATUS_RESET=60
LIVENESS_ERRORS_IGNORED=<comma-separated list>
registry.metrics.PersistenceExceptionLivenessCheck.errorThreshold=1
registry.metrics.ResponseErrorLivenessCheck.errorThreshold=1
```

##### Readiness Probes
```properties
READINESS_ERROR_THRESHOLD=5
READINESS_COUNTER_RESET=30
READINESS_STATUS_RESET=60
READINESS_TIMEOUT=10
registry.metrics.PersistenceTimeoutReadinessCheck.timeoutSec=15
registry.metrics.ResponseTimeoutReadinessCheck.timeoutSec=10
```

##### Metrics
```properties
quarkus.micrometer.enabled=true
quarkus.micrometer.export.prometheus.enabled=true
quarkus.datasource.metrics.enabled=true
registry.storage.metrics.cache.max-size=1000
registry.storage.metrics.cache.check-period=30000
```

#### Additional Configuration Categories

##### Eventing & Kafka Sink
```properties
K_SINK=<knative sink URL>
KAFKA_BOOTSTRAP_SERVERS=<bootstrap servers>
registry.events.kafka.topic=<topic name>
registry.events.kafka.topic-partition=<partition number>
registry.events.kafka.config.enable.idempotence=true
registry.events.kafka.config.retries=3
registry.events.kafka.config.acks=all
```

##### UI Configuration
```properties
REGISTRY_UI_FEATURES_READONLY=true/false
REGISTRY_UI_CONFIG_APIURL=_
REGISTRY_UI_CONFIG_UI_CONTEXT_PATH=/ui/
registry.ui.features.settings=true/false
registry.ui.config.uiCodegenEnabled=true/false
registry.ui.root=/ui/
```

##### Logging
```properties
LOG_LEVEL=INFO|DEBUG|TRACE|WARN|ERROR
REGISTRY_LOG_LEVEL=INFO
quarkus.log.level=${LOG_LEVEL}
quarkus.log.category."io.apicurio".level=${REGISTRY_LOG_LEVEL}
ENABLE_ACCESS_LOG=true/false
quarkus.http.access-log.enabled=${ENABLE_ACCESS_LOG}
quarkus.http.access-log.exclude-pattern=/health/.*
```

##### Network & Routing
```properties
HTTP_PORT=8080
QUARKUS_HTTP_PORT=${HTTP_PORT}
quarkus.http.limits.max-body-size=52428800

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:8080
CORS_ALLOWED_METHODS=GET,PUT,POST,PATCH,DELETE,OPTIONS
CORS_ALLOWED_HEADERS=x-registry-name,x-registry-description,authorization,content-type,...

# URL Overrides
REGISTRY_URL_OVERRIDE_HOST=<external hostname>
REGISTRY_URL_OVERRIDE_PORT=<external port>
REGISTRY_PROXY_ADDRESS_FORWARDING=true/false

# Redirects
REGISTRY_ENABLE_REDIRECTS=true
REGISTRY_ROOT_REDIRECT=/ui/
```

##### Artifact Management
```properties
registry.rest.artifact.deletion.enabled=true/false
registry.rest.artifact.download.maxSize=1000000
registry.rest.artifact.download.skipSSLValidation=false
artifacts.skip.disabled.latest=true
registry.download.href.ttl=30
```

##### Cache Configuration
```properties
registry.config.cache.enabled=true
registry.tenants.context.cache.max-size=1000
registry.tenants.context.cache.check-period=60000
REGISTRY_STORAGE_METRICS_CACHE_MAX_SIZE=1000
REGISTRY_TENANTS_CONTEXT_CACHE_MAX_SIZE=1000
```

##### Dynamic Configuration
```properties
REGISTRY_ALLOW_DYNAMIC_CONFIG=true/false
```

##### Import/Export
```properties
registry.import.url=<URL to import data from>
```

##### Resource Limits (OpenShift Templates)
```properties
REGISTRY_MEM_LIMIT=1300Mi
REGISTRY_MEM_REQUEST=600Mi
REGISTRY_CPU_LIMIT=1
REGISTRY_CPU_REQUEST=100m
```

### REST API Analysis (Version 2.6.x)

#### API Information
- **API Version**: 2.6.x
- **OpenAPI Specification**: 3.0.3
- **Title**: Apicurio Registry API [v2]
- **Base Path**: `/apis/registry/v2`
- **Specification Location**:
  `apicurio-registry-2.6/common/src/main/resources/META-INF/openapi.json`

#### Main Endpoint Categories

##### Administrative (`/admin`)
- **Artifact Types**: List available artifact types
- **Configuration**: Manage registry configuration properties
- **Export/Import**: Export and import registry data
- **Logging**: Manage logger configurations
- **Role Mappings**: Manage user/principal role assignments
- **Global Rules**: Manage globally configured rules

##### Groups (`/groups`)
- List, create, retrieve, and delete artifact groups
- Manage artifacts within groups

##### Artifacts (`/groups/{groupId}/artifacts`)
- Create, read, update, delete artifacts
- Manage artifact metadata, state, ownership
- Test artifact updates against rules
- Search artifacts by content

##### Versions (`/groups/{groupId}/artifacts/{artifactId}/versions`)
- List and manage artifact versions
- Version-specific metadata, state, comments
- Version references (inbound/outbound)

##### Artifact Rules (`/groups/{groupId}/artifacts/{artifactId}/rules`)
- Manage rules per artifact (VALIDITY, COMPATIBILITY, INTEGRITY)

##### Global IDs (`/ids`)
- Access content by globalId, contentId, or contentHash
- Retrieve references for artifacts

##### Search (`/search`)
- Search artifacts by various criteria
- Search by content (with canonicalization support)

##### System (`/system`)
- Retrieve system information (version, build date)
- Get resource limits

##### Users (`/users`)
- Get current user information

#### Key Operations by Category

##### Administrative Operations
- `GET /admin/artifactTypes` - List artifact types
- `GET/PUT/DELETE /admin/config/properties` - Manage configuration
- `GET /admin/export` - Export registry data as ZIP
- `POST /admin/import` - Import registry data from ZIP
- `GET/PUT/DELETE /admin/loggers` - Manage logging levels
- `GET/POST/PUT/DELETE /admin/roleMappings` - Manage role mappings
- `GET/POST/PUT/DELETE /admin/rules` - Manage global rules

##### Group Operations
- `GET /groups` - List all groups (paginated)
- `POST /groups` - Create new group
- `GET/DELETE /groups/{groupId}` - Retrieve/delete specific group

##### Artifact Operations
- `POST /groups/{groupId}/artifacts` - Create artifact
- `GET /groups/{groupId}/artifacts` - List artifacts in group
- `DELETE /groups/{groupId}/artifacts` - Delete all artifacts in group
- `GET /groups/{groupId}/artifacts/{artifactId}` - Get latest artifact content
- `PUT /groups/{groupId}/artifacts/{artifactId}` - Update artifact (creates new version)
- `DELETE /groups/{groupId}/artifacts/{artifactId}` - Delete artifact completely
- `GET/PUT /groups/{groupId}/artifacts/{artifactId}/meta` - Manage artifact metadata
- `POST /groups/{groupId}/artifacts/{artifactId}/meta` - Get version metadata by content
- `GET/PUT /groups/{groupId}/artifacts/{artifactId}/owner` - Manage artifact ownership
- `PUT /groups/{groupId}/artifacts/{artifactId}/state` - Update artifact state
- `PUT /groups/{groupId}/artifacts/{artifactId}/test` - Test artifact update against rules

##### Version Operations
- `GET /groups/{groupId}/artifacts/{artifactId}/versions` - List versions (paginated)
- `POST /groups/{groupId}/artifacts/{artifactId}/versions` - Create new version
- `GET/DELETE /groups/{groupId}/artifacts/{artifactId}/versions/{version}` - Get/delete specific version
- `GET/PUT/DELETE .../versions/{version}/meta` - Manage version metadata
- `PUT .../versions/{version}/state` - Update version state
- `GET .../versions/{version}/references` - Get version references
- `GET/POST/PUT/DELETE .../versions/{version}/comments` - Manage version comments

##### Global Access Operations
- `GET /ids/globalIds/{globalId}` - Get content by global ID
- `GET /ids/contentIds/{contentId}` - Get content by content ID
- `GET /ids/contentHashes/{contentHash}` - Get content by SHA-256 hash
- `GET /ids/.../references` - Get references for globalId/contentId/contentHash

##### Search Operations
- `GET /search/artifacts` - Search artifacts by filters (name, labels, properties, group, etc.)
- `POST /search/artifacts` - Search artifacts by content

#### Authentication/Security Schemes

The API supports three authentication schemes:

##### 1. OAuth2 (Authorization Code Flow)
- Authorization URL: `https://keycloak.example/realms/registry/protocol/openid-connect/auth`
- Token URL: `https://keycloak.example/realms/registry/protocol/openid-connect/token`
- Refresh URL: `https://keycloak.example/realms/registry/protocol/openid-connect/token`

**Scopes:**
- `sr-admin` - Full access to all CRUD operations
- `sr-developer` - Access to CRUD except global rules configuration
- `sr-readonly` - Read and search operations only

##### 2. OIDC (OpenID Connect)
- OpenID Connect URL: `https://keycloak.example/realms/registry/.well-known/openid-configuration`
- Same scopes as OAuth2

##### 3. BasicAuth (HTTP Basic Authentication)
- Fallback option for tools that don't support OIDC
- Uses standard HTTP Basic authentication scheme

#### Notable Data Models and Schemas

##### Core Artifact Models
- **ArtifactMetaData**: Complete artifact metadata (id, groupId, type, version, state, timestamps,
  creator, labels, properties, references)
- **ArtifactContent**: Raw content + references to other artifacts
- **ArtifactReference**: Reference to another artifact (groupId, artifactId, version, name)
- **ArtifactType**: String type (AVRO, PROTOBUF, JSON, OPENAPI, ASYNCAPI, GRAPHQL, WSDL, XSD, KCONNECT)
- **ArtifactState**: Enum (ENABLED, DISABLED, DEPRECATED)

##### Version Models
- **VersionMetaData**: Version-specific metadata
- **Version**: String identifier for version (can be integer or SemVer)
- **SearchedVersion**: Version search result with metadata

##### Group Models
- **GroupMetaData**: Group information (id, description, properties, timestamps)
- **CreateGroupMetaData**: Data for creating new group

##### Rule Models
- **Rule**: Configuration for validation rules
- **RuleType**: Enum (VALIDITY, COMPATIBILITY, INTEGRITY)
- **RuleViolationError**: Detailed error with violation causes
- **RuleViolationCause**: Specific violation context and description

##### Search Models
- **ArtifactSearchResults**: Paginated artifact search results
- **GroupSearchResults**: Paginated group search results
- **VersionSearchResults**: Paginated version search results
- **SearchedArtifact**: Artifact in search results

##### Administrative Models
- **ConfigurationProperty**: Registry configuration setting
- **RoleMapping**: Principal to role assignment
- **RoleType**: Enum (READ_ONLY, DEVELOPER, ADMIN)
- **LogConfiguration**: Logging level configuration
- **Limits**: Resource usage limits

##### Metadata Models
- **EditableMetaData**: User-editable metadata fields (name, description, labels, properties)
- **Comment**: Version comment with ID, creator, timestamp, value
- **ArtifactOwner**: Ownership information

##### Miscellaneous
- **IfExists**: Enum (FAIL, UPDATE, RETURN, RETURN_OR_UPDATE) - behavior when artifact exists
- **ReferenceType**: Enum (OUTBOUND, INBOUND) - reference direction
- **SortOrder**: Enum (asc, desc)
- **SortBy**: Enum (name, createdOn)
- **Properties**: Map of string key-value pairs
- **UserInfo**: Current user information

#### Additional Notable Features

##### Content Hash Support
- SHA-256 content hashing for deduplication
- MD5 hash algorithm also supported
- Content can be accessed by hash via `/ids/contentHashes/{contentHash}`

##### References Support
- Artifacts can reference other artifacts (useful for Protobuf dependencies)
- References tracked as inbound/outbound
- Can retrieve all references for an artifact

##### Content Dereferencing
- Query parameter `dereference` available on content retrieval operations
- Automatically resolves referenced artifacts

##### Comments on Versions
- Version-specific commenting system
- Comments have owners and can only be modified by owner
- Maximum comment length: 1024 characters

##### Content Canonicalization
- Support for canonical content comparison
- Used when searching for existing versions
- Algorithm varies by artifact type

##### Browser-Friendly Export
- `forBrowser` parameter creates download links
- Returns `DownloadRef` with `href` for browser downloads

##### Flexible Version Naming
- Versions can be simple integers or SemVer
- Server can auto-generate version numbers

---

## Apicurio Registry 3.1.x Analysis

### Deployment Configuration Options

#### Repository Information
- **Branch**: main (3.1.x)
- **Repository**: git@github.com:Apicurio/apicurio-registry.git
- **Local Path**: `/home/ewittman/git/apicurio/apicurio-testing/.work/.work/apicurio-registry-3.1`

### MAJOR CHANGES FROM VERSION 2.6.x TO 3.1.x

#### 1. Configuration Namespace Change

**CRITICAL BREAKING CHANGE**: All configuration properties have been renamed from `registry.*` to `apicurio.*`

**Examples:**
- `registry.auth.enabled` → `quarkus.oidc.tenant-enabled`
- `registry.auth.role-based-authorization` → `apicurio.auth.role-based-authorization`
- `registry.api.errors.include-stack-in-response` → `apicurio.api.errors.include-stack-in-response`
- `registry.ccompat.*` → `apicurio.ccompat.*`
- `registry.limits.*` → `apicurio.limits.*`

#### 2. NEW Configuration Categories in 3.1.x

##### GitOps Storage (NEW in 3.0.0)
```properties
apicurio.gitops.id=main
apicurio.gitops.repo.origin.uri=https://github.com/org/repo
apicurio.gitops.repo.origin.branch=main
apicurio.gitops.workdir=/tmp/apicurio-registry-gitops
```

**Blue/Green Datasource Configurations:**
- `apicurio.datasource.blue.*`
- `apicurio.datasource.green.*`

##### Semantic Versioning (NEW in 3.0.0)
```properties
apicurio.semver.validation.enabled=true/false
apicurio.semver.branching.enabled=true/false
apicurio.semver.branching.coerce=true/false
```

##### Observability/Metrics (NEW in 3.1.1)
```properties
apicurio.metrics.rest.enabled=true
apicurio.metrics.rest.explicit-status-codes-list=401
apicurio.metrics.rest.method-tag-enabled=true
apicurio.metrics.rest.path-tag-enabled=true
apicurio.metrics.rest.path-filter-pattern=/apis/.*
```

##### Dynamic Log Level (NEW in 3.1.0)
```properties
apicurio.log.level=WARN
```

##### Custom Artifact Types (NEW in 3.1.0)
```properties
apicurio.artifact-types.config-file=/tmp/apicurio-registry-artifact-types.json
```

##### UI Editors Support (NEW in 3.1.0)
```properties
apicurio.ui.editorsUrl=/editors/
```

##### Application Context Path (NEW in 3.1.0)
```properties
apicurio.app.context-path=/
```

#### 3. REMOVED Configuration Options from 2.6.x

##### Events Configuration (REMOVED/CHANGED)
- `registry.events.ksink` - Removed
- `registry.events.kafka.topic-partition` - Removed
- Event configuration simplified to just `apicurio.events.kafka.topic`

##### Authentication Property Changes
- `registry.auth.client-id` → `quarkus.oidc.client-id`
- `registry.auth.client-secret` → `quarkus.oidc.client-secret`
- `registry.auth.enabled` → `quarkus.oidc.tenant-enabled`
- `registry.auth.token.endpoint` → `quarkus.oidc.token-path`
- `registry.auth.tenant-owner-is-admin.enabled` - Removed

##### UI Configuration Changes
- `registry.ui.config.apiUrl` - Removed
- `registry.ui.config.auth.type` - Removed
- `registry.ui.config.auth.oidc.url` - Removed
- `registry.ui.config.auth.oidc.token-type` - Removed
- `registry.ui.config.uiCodegenEnabled` - Removed
- `registry.ui.config.uiContextPath` → `apicurio.ui.contextPath`
- `registry.ui.features.readOnly` → `apicurio.ui.features.read-only.enabled`
- `registry.ui.root` - Removed

#### 4. RENAMED/MODIFIED Configuration Options

##### Storage
- `quarkus.datasource.db-kind` → `apicurio.storage.sql.kind`
- `quarkus.datasource.jdbc.url` → `apicurio.datasource.url`
- `registry.sql.init` → `apicurio.sql.init`
- **NEW**: `apicurio.storage.kind` - Specifies storage variant (sql, kafkasql, gitops)

##### Import/Export (NEW in 3.0.0)
```properties
apicurio.import.preserveContentId=true
apicurio.import.preserveGlobalId=true
apicurio.import.requireEmptyRegistry=true
apicurio.import.work-dir=/tmp/import-work-dir
```

##### Health Checks
Renamed from CamelCase to kebab-case with standardized naming:
- `registry.metrics.PersistenceExceptionLivenessCheck.*` →
  `apicurio.metrics.persistence-exception-liveness-check.*`
- `registry.metrics.ResponseErrorLivenessCheck.*` →
  `apicurio.metrics.response-error-liveness-check.*`

##### REST API
- `registry.rest.artifact.download.maxSize` → `apicurio.rest.artifact.download.max-size.bytes`
- `registry.rest.artifact.download.skipSSLValidation` →
  `apicurio.rest.artifact.download.ssl-validation.disabled`
- `registry.rest.artifact.deletion.enabled` → Split into three separate properties:
  - `apicurio.rest.deletion.group.enabled` (NEW in 3.0.0)
  - `apicurio.rest.deletion.artifact.enabled` (NEW in 3.0.0)
  - `apicurio.rest.deletion.artifact-version.enabled`

**Additional NEW properties (3.0.2+):**
```properties
apicurio.rest.mutability.artifact-version-content.enabled=true/false
apicurio.rest.search-results.labels.max-size.bytes=512
```

##### Basic Authentication
- `registry.auth.basic-auth-client-credentials.*` → `apicurio.authn.basic-client-credentials.*`
- **NEW**: `quarkus.http.auth.basic` - Enable basic auth (3.0.0)
- **NEW in 3.0.0**: `apicurio.auth.admin-override.user` - Admin override user name

##### Download/Redirects
- `registry.download.href.ttl` → `apicurio.download.href.ttl.seconds`
- `registry.enable-redirects` → `apicurio.redirects.enabled`

##### Limits
Renamed property suffix to include `.bytes`:
- `registry.limits.config.max-label-size` → `apicurio.limits.config.max-label-size.bytes`
- `registry.limits.config.max-property-key-size` → `apicurio.limits.config.max-property-key-size.bytes`
- `registry.limits.config.max-property-value-size` →
  `apicurio.limits.config.max-property-value-size.bytes`
- `registry.limits.config.max-schema-size-bytes` → `apicurio.limits.config.max-schema-size.bytes`

##### SQL Schema Support (NEW in 3.0.6)
```properties
apicurio.sql.db-schema=schema_name
```

##### Storage Read-Only Mode (NEW in 3.0.0)
```properties
apicurio.storage.read-only.enabled=true/false
```

##### Auto Group Creation (NEW in 3.0.15)
```properties
apicurio.storage.enable-automatic-group-creation=true
```

### Deployment Types Supported

#### 1. Kubernetes/OpenShift

**Available Templates:**
- `examples/openshift-template/apicurio-registry-template-sql.yml`
- `examples/openshift-template/apicurio-registry-template-mem.yml`
- `examples/openshift-template/apicurio-registry-template-kafkasql.yml`
- `examples/mtls-minikube/k8s/apicurio-registry-mtls.yaml` (mTLS example)

**Key Features:**
- Uses OpenShift DeploymentConfig
- Includes Route configuration with TLS termination
- Health checks: `/health/live` and `/health/ready`
- Resource limits/requests configurable
- Service type: NodePort (port 32222)

#### 2. Docker Compose

**Available Examples:**
- `in-memory-no-auth` - In-memory storage, no authentication
- `in-memory-with-auth` - In-memory with OIDC authentication (Keycloak)
- `in-memory-basicauth` - In-memory with basic auth client credentials
- `in-memory-with-rbac` - In-memory with role-based access control
- `in-memory-with-rbac-app` - In-memory with application-level RBAC
- `in-memory-with-rbac-owneronly` - In-memory with owner-only authorization
- `in-memory-with-studio` - In-memory with Apicurio Studio integration
- `pg-no-auth` - PostgreSQL storage, no authentication
- `mysql-no-auth` - MySQL storage, no authentication

**Architecture Change:**
All Docker Compose examples deploy separate containers:
- `apicurio-registry` (API on port 8080/8081)
- `apicurio-registry-ui` (UI on port 8888)

### Storage Backend Options

#### 1. SQL Storage (Default)

**Supported Databases:**
- H2 (in-memory, default for development)
- PostgreSQL
- MySQL
- Microsoft SQL Server

**Configuration:**
```properties
APICURIO_STORAGE_KIND=sql
APICURIO_STORAGE_SQL_KIND=postgresql|mysql|h2|mssql
APICURIO_DATASOURCE_URL=jdbc:postgresql://host:5432/dbname
APICURIO_DATASOURCE_USERNAME=user
APICURIO_DATASOURCE_PASSWORD=pass
```

**Connection Pool Settings:**
```properties
apicurio.datasource.jdbc.initial-size=20
apicurio.datasource.jdbc.min-size=20
apicurio.datasource.jdbc.max-size=100
```

#### 2. KafkaSQL Storage

**Configuration:**
```properties
APICURIO_STORAGE_KIND=kafkasql
APICURIO_KAFKASQL_BOOTSTRAP_SERVERS=kafka:9092
APICURIO_KAFKASQL_TOPIC=kafkasql-journal
APICURIO_KAFKASQL_SNAPSHOTS_TOPIC=kafkasql-snapshots
APICURIO_KAFKASQL_SNAPSHOT_EVERY_SECONDS=86400s
```

**Security Options:**
```properties
apicurio.kafkasql.security.sasl.enabled=true/false
apicurio.kafkasql.security.sasl.mechanism=PLAIN|SCRAM-SHA-256|SCRAM-SHA-512
apicurio.kafkasql.security.sasl.client-id=client-id
apicurio.kafkasql.security.sasl.client-secret=secret
apicurio.kafkasql.security.sasl.token.endpoint=https://oauth/token
apicurio.kafkasql.security.protocol=PLAINTEXT|SSL|SASL_PLAINTEXT|SASL_SSL
```

**SSL Options:**
```properties
apicurio.kafkasql.ssl.keystore.location=/path/to/keystore
apicurio.kafkasql.ssl.keystore.password=password
apicurio.kafkasql.ssl.truststore.location=/path/to/truststore
apicurio.kafkasql.ssl.truststore.password=password
```

#### 3. GitOps Storage (NEW in 3.0.0)

**Configuration:**
```properties
APICURIO_STORAGE_KIND=gitops
APICURIO_GITOPS_ID=main
APICURIO_GITOPS_REPO_ORIGIN_URI=https://github.com/org/repo
APICURIO_GITOPS_REPO_ORIGIN_BRANCH=main
APICURIO_GITOPS_WORKDIR=/tmp/apicurio-registry-gitops
```

**Blue/Green Datasources:**
Supports dual datasource configuration for blue/green deployments:
```properties
apicurio.datasource.blue.*
apicurio.datasource.green.*
```

### Authentication & Authorization Options

#### 1. OIDC/OAuth2 Authentication

**Configuration:**
```properties
QUARKUS_OIDC_TENANT_ENABLED=true
QUARKUS_OIDC_AUTH_SERVER_URL=https://keycloak:8080/realms/registry
QUARKUS_OIDC_CLIENT_ID=registry-api
QUARKUS_OIDC_CLIENT_SECRET=secret
QUARKUS_OIDC_TOKEN_PATH=/protocol/openid-connect/token/
```

**UI OIDC Configuration:**
```properties
APICURIO_UI_AUTH_OIDC_CLIENT_ID=apicurio-registry
APICURIO_UI_AUTH_OIDC_REDIRECT_URI=http://localhost:8888/
APICURIO_UI_AUTH_OIDC_SCOPE=openid profile email
```

#### 2. Basic Authentication with Client Credentials

**NEW in 3.x:**
```properties
QUARKUS_HTTP_AUTH_BASIC=true
APICURIO_AUTHN_BASIC_CLIENT_CREDENTIALS_ENABLED=true
APICURIO_AUTHN_BASIC_CLIENT_CREDENTIALS_CACHE_EXPIRATION=10
APICURIO_AUTHN_BASIC_CLIENT_CREDENTIALS_CACHE_EXPIRATION_OFFSET=10
```

#### 3. Authorization Modes

##### Role-Based Authorization (RBAC)
```properties
apicurio.auth.role-based-authorization=true
apicurio.auth.roles.admin=sr-admin
apicurio.auth.roles.developer=sr-developer
apicurio.auth.roles.readonly=sr-readonly
apicurio.auth.role-source=token|header
apicurio.auth.role-source.header.name=X-Registry-Role
```

##### Owner-Only Authorization
```properties
apicurio.auth.owner-only-authorization=true
apicurio.auth.owner-only-authorization.limit-group-access=true
```

##### Anonymous/Authenticated Read Access
```properties
apicurio.auth.anonymous-read-access.enabled=true
apicurio.auth.authenticated-read-access.enabled=true
```

##### Admin Override (NEW in 3.0.0)
```properties
apicurio.auth.admin-override.enabled=true
apicurio.auth.admin-override.from=token
apicurio.auth.admin-override.type=role|claim
apicurio.auth.admin-override.role=sr-admin
apicurio.auth.admin-override.claim=org-admin
apicurio.auth.admin-override.claim-value=true
apicurio.auth.admin-override.user=admin
```

### Other Notable Deployment Configurations

#### 1. mTLS Support

Example: `examples/mtls-minikube/k8s/apicurio-registry-mtls.yaml`

**Configuration:**
```properties
QUARKUS_HTTP_SSL_CLIENT_AUTH=required
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_FILE=/deployments/certs/server-keystore.p12
QUARKUS_HTTP_SSL_CERTIFICATE_KEY_STORE_PASSWORD=password
QUARKUS_HTTP_SSL_CERTIFICATE_TRUST_STORE_FILE=/deployments/certs/server-truststore.p12
QUARKUS_HTTP_SSL_CERTIFICATE_TRUST_STORE_PASSWORD=password
QUARKUS_HTTP_INSECURE_REQUESTS=disabled
```

#### 2. CORS Configuration

```properties
QUARKUS_HTTP_CORS_ORIGINS=*
quarkus.http.cors.methods=GET,PUT,POST,PATCH,DELETE,OPTIONS
```

#### 3. URL Override for Proxies

```properties
apicurio.url.override.host=external-hostname.com
apicurio.url.override.port=443
```

#### 4. API Disabling

```properties
apicurio.disable.apis=ccompat,ibmcompat
```

#### 5. Limits Configuration

```properties
apicurio.limits.config.max-artifacts=-1
apicurio.limits.config.max-versions-per-artifact=-1
apicurio.limits.config.max-total-schemas=-1
apicurio.limits.config.max-schema-size.bytes=-1
apicurio.limits.config.max-artifact-properties=-1
apicurio.limits.config.max-artifact-labels=-1
apicurio.limits.config.max-requests-per-second=-1
```

#### 6. Deletion Control (Granular in 3.x)

```properties
apicurio.rest.deletion.group.enabled=true
apicurio.rest.deletion.artifact.enabled=true
apicurio.rest.deletion.artifact-version.enabled=true
```

#### 7. Compatibility API Features

```properties
apicurio.ccompat.legacy-id-mode.enabled=false
apicurio.ccompat.use-canonical-hash=false
apicurio.ccompat.max-subjects=1000
apicurio.ccompat.group-concat.enabled=false
apicurio.ccompat.group-concat.separator=:
```

#### 8. Health Check Configuration

```properties
apicurio.liveness.errors.ignored=
apicurio.metrics.persistence-exception-liveness-check.error-threshold=1
apicurio.metrics.persistence-timeout-readiness-check.timeout.seconds=15
apicurio.metrics.response-error-liveness-check.error-threshold=1
```

### REST API Analysis (Version 3.1.x)

#### Two API Versions Available

##### 1. v2 API (Backward Compatibility)
- **Base Path**: `/apis/registry/v2`
- **Status**: DEPRECATED but maintained for backward compatibility
- **Specification Location**:
  `app/src/main/resources-unfiltered/META-INF/resources/api-specifications/registry/v2/openapi.json`
- **Line Count**: 4,535 lines (smaller than 2.6.x v2 API)

##### 2. v3 API (Primary API)
- **Base Path**: `/apis/registry/v3`
- **Status**: Current primary API
- **Specification Location**:
  `app/src/main/resources-unfiltered/META-INF/resources/api-specifications/registry/v3/openapi.json`
- **Line Count**: 5,513 lines

#### v3 API Major Enhancements

##### Data Model Changes
1. **Empty Artifacts**: Artifacts can now exist without any versions
2. **Group Metadata**: Groups now have first-class metadata support
3. **Branch Support**: Custom branches are now supported, "latest" is considered a branch
4. **Labels on Groups**: Groups can have labels for organization

##### New Endpoint Categories

**Branch Management (`/groups/{groupId}/artifacts/{artifactId}/branches`)**
- List branches for an artifact
- Create, retrieve, update, delete branches
- Manage branch metadata
- Get branch versions

**Enhanced Group Management**
- Full CRUD operations on group metadata
- Search groups by criteria
- List groups with pagination

**Enhanced Version Search**
- Dedicated version search endpoints
- More granular version filtering

##### API Changes from v2 to v3

**Replaced `/test` Endpoint:**
- Old: `PUT /groups/{groupId}/artifacts/{artifactId}/test`
- New: Use `dryRun=true` query parameter on regular operations

**Query Parameter Changes:**
- `dereference` (v2) → `references` (v3) with enum values (DEREFERENCE, EMBED, etc.)
- New `returnArtifactType` parameter returns artifact type in response header

**Streamlined Operations:**
- Simplified artifact creation workflow
- Enhanced version creation with more options
- Better pagination support across all list operations

#### Additional API Specifications in 3.1.x

##### Confluent Compatibility API v7
- **Specification**: `api-specifications/ccompat/v7/openapi.json`
- Provides Confluent Schema Registry API compatibility

##### GitOps API v0
- **Specification**: `api-specifications/gitops/v0/openapi.json`
- NEW API for GitOps storage operations

### Migration Considerations from 2.6.x to 3.1.x

#### Summary Comparison Table

| Category | 2.6.x | 3.1.x | Change Type |
|----------|-------|-------|-------------|
| Config Prefix | `registry.*` | `apicurio.*` | Breaking Change |
| Storage Types | SQL, KafkaSQL | SQL, KafkaSQL, GitOps | Feature Addition |
| SemVer Support | None | Full support | New Feature |
| UI Deployment | Embedded | Separate container | Architectural Change |
| Deletion Control | Single flag | Three separate flags | Enhancement |
| Metrics | Basic | Enhanced REST metrics | Enhancement |
| Log Level | Static | Dynamic | Enhancement |
| Basic Auth | Limited | Enhanced client credentials | Enhancement |
| API Base Path | Fixed | Configurable context path | Enhancement |
| API Version | v2 only | v2 (deprecated) + v3 (primary) | Major Change |
| Branch Support | None | Full branch API | New Feature |
| Empty Artifacts | Not supported | Supported | Data Model Change |

#### Critical Actions Required

1. **Update All Environment Variables**
   - Change `REGISTRY_` prefix to `APICURIO_` or `QUARKUS_` as appropriate
   - Review all configuration and update to new naming conventions

2. **Update Authentication Configuration**
   - `REGISTRY_AUTH_ENABLED` → `QUARKUS_OIDC_TENANT_ENABLED`
   - `REGISTRY_AUTH_CLIENT_ID` → `QUARKUS_OIDC_CLIENT_ID`
   - `REGISTRY_AUTH_CLIENT_SECRET` → `QUARKUS_OIDC_CLIENT_SECRET`
   - `REGISTRY_AUTH_TOKEN_ENDPOINT` → `QUARKUS_OIDC_TOKEN_PATH`

3. **Update UI Configuration**
   - Separate UI container is now standard
   - UI configuration simplified with new properties
   - Update deployment manifests to include separate UI service

4. **Review Deletion Capabilities**
   - Now split into three separate flags for groups, artifacts, and versions
   - Update configuration if deletion was enabled in 2.6.x

5. **Leverage New Features**
   - Consider GitOps storage for GitOps workflows
   - Enable SemVer validation/branching if needed
   - Configure new REST API metrics for observability
   - Use dynamic log level configuration

6. **Health Check Property Renaming**
   - Update from CamelCase to kebab-case naming convention

---

## Migration Guide Summary

### Migration Overview

**No automatic upgrade is possible** from Apicurio Registry 2.6.x to 3.1.x due to breaking changes. A manual
migration process is required.

### Key Migration Changes

#### 1. Data Storage
- All 2.6.x storage options remain supported in 3.1.x
- Existing data in Kafka topics or databases is incompatible with 3.x format
- Must export data using Apicurio Registry's export feature
- Import preserves artifact identifiers, metadata, and references

#### 2. REST API Changes
- New v3 REST API with expanded capabilities
- v2 core REST API is now deprecated but maintained for backward compatibility
- Continued support for compatibility APIs (Confluent, IBM)

#### 3. SDK Changes
- New SDKs generated using Kiota
- SDKs now available for Java, TypeScript, Python, Golang
- Previous Java client classes are no longer available

#### 4. Deployment Configuration
- Configuration options have been renamed/modified
- New configuration options introduced
- Some features removed (multitenancy)

### Migration Procedure

#### Step 1: Export Data from 2.6.x

**Using the Admin Export API:**

```bash
curl -X GET http://<registry-v2-url>/apis/registry/v2/admin/export -o registry-export.zip
```

**What Gets Exported:**
- All artifacts and their versions
- Artifact metadata (labels, properties, descriptions)
- Global rules configuration
- Artifact-specific rules
- Artifact references
- Version metadata and comments
- Global IDs and content IDs

#### Step 2: Deploy Apicurio Registry 3.1.x

**Key Deployment Steps:**

1. **Update Configuration Properties**
   - Convert all `registry.*` properties to `apicurio.*`
   - Update authentication properties to use `quarkus.oidc.*`
   - Update health check property names to kebab-case

2. **Deploy New Instance**
   - Use updated OpenShift templates or Docker Compose files
   - Ensure storage backend is configured (SQL, KafkaSQL, or GitOps)
   - Configure authentication (OIDC/OAuth2)
   - Deploy separate UI container if using Docker Compose

3. **Verify Deployment**
   - Check health endpoints: `/health/live` and `/health/ready`
   - Verify system info: `GET /apis/registry/v3/system/info`
   - Ensure authentication is working

#### Step 3: Import Data into 3.1.x

**Using the Admin Import API:**

```bash
curl -X POST http://<registry-v3-url>/apis/registry/v3/admin/import \
  -H "Content-Type: application/zip" \
  --data-binary @registry-export.zip
```

**Import Configuration Options:**

```properties
apicurio.import.preserveContentId=true
apicurio.import.preserveGlobalId=true
apicurio.import.requireEmptyRegistry=true
```

**What Gets Imported:**
- All artifacts with their original IDs
- All versions with preserved global IDs
- Metadata, labels, properties
- Rules (global and artifact-specific)
- References between artifacts

#### Step 4: Validate Migration

**Validation Checklist:**

1. **Artifact Count Verification**
   ```bash
   # Count artifacts in 2.6.x
   curl http://<registry-v2-url>/apis/registry/v2/search/artifacts?limit=1

   # Count artifacts in 3.1.x
   curl http://<registry-v3-url>/apis/registry/v3/search/artifacts?limit=1
   ```
   Compare the `count` field in both responses.

2. **Global Rules Verification**
   ```bash
   # List global rules in 3.1.x
   curl http://<registry-v3-url>/apis/registry/v3/admin/rules
   ```
   Verify all global rules from 2.6.x are present.

3. **Artifact References Verification**
   - Select artifacts with references in 2.6.x
   - Retrieve same artifacts in 3.1.x
   - Verify references are intact

4. **Metadata Verification**
   - Compare artifact metadata (labels, properties, descriptions)
   - Verify version metadata
   - Check artifact states

#### Step 5: Update Client Applications

##### 5.1 Update Maven Dependencies

**Old (2.6.x):**
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-client</artifactId>
    <version>2.6.x</version>
</dependency>
```

**New (3.1.x):**
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-java-sdk</artifactId>
    <version>3.1.x</version>
</dependency>
```

##### 5.2 Update Client Code

**Old (2.6.x):**
```java
RegistryClient client = RegistryClientFactory.create(
    "http://registry.example.com/apis/registry/v2"
);
```

**New (3.1.x):**
```java
VertXRequestAdapter adapter = new VertXRequestAdapter(vertx);
adapter.setBaseUrl("http://registry.example.com/apis/registry/v3");
RegistryClient client = new RegistryClient(adapter);
```

##### 5.3 Update SerDes Libraries

**Old (2.6.x):**
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-serdes-avro-serde</artifactId>
    <version>2.6.x</version>
</dependency>
```

**New (3.1.x):**
```xml
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-avro-serde-kafka</artifactId>
    <version>3.1.x</version>
</dependency>
```

##### 5.4 Client Application Migration Strategy

**Phased Approach:**

1. **Phase 1: Use v2 API in 3.1.x**
   - Update only the registry URL
   - Keep existing client code
   - Leverage backward compatibility
   - Validate everything works

2. **Phase 2: Migrate to v3 API**
   - Update client libraries to 3.x
   - Refactor code to use new SDK
   - Change API base path from `/v2` to `/v3`
   - Test thoroughly

3. **Phase 3: Adopt New Features**
   - Implement branch management if needed
   - Use empty artifacts for governance
   - Leverage enhanced search capabilities

#### Step 6: Cutover Strategy

**Recommended Cutover Approach:**

1. **Parallel Running**
   - Keep 2.6.x running in production
   - Deploy 3.1.x in staging/test
   - Perform migration and validation
   - Test all client applications

2. **DNS/Routing Switch**
   - Update DNS or load balancer to point to 3.1.x
   - Monitor for issues
   - Keep 2.6.x available for rollback

3. **Gradual Migration**
   - Migrate non-critical applications first
   - Monitor for issues
   - Gradually migrate critical applications
   - Decommission 2.6.x after all applications migrated

#### Step 7: Rollback Plan

**Rollback Preparation:**

1. **Keep 2.6.x Running**
   - Don't decommission immediately
   - Maintain full backup of 2.6.x data

2. **Export Before Migration**
   - Keep export file from pre-migration state
   - Can re-import into 2.6.x if needed

3. **DNS/Routing Rollback**
   - Document DNS changes
   - Have rollback procedure ready
   - Test rollback in staging

4. **Client Application Rollback**
   - Keep 2.6.x client libraries available
   - Document code changes for easy revert
   - Have rollback deployment pipelines ready

### Configuration Migration Reference

#### Authentication Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.auth.enabled` | `quarkus.oidc.tenant-enabled` | Moved to Quarkus OIDC |
| `registry.auth.client-id` | `quarkus.oidc.client-id` | Moved to Quarkus OIDC |
| `registry.auth.client-secret` | `quarkus.oidc.client-secret` | Moved to Quarkus OIDC |
| `registry.auth.token.endpoint` | `quarkus.oidc.token-path` | Moved to Quarkus OIDC |
| `registry.auth.roles.admin` | `apicurio.auth.roles.admin` | Namespace change |
| `registry.auth.roles.developer` | `apicurio.auth.roles.developer` | Namespace change |
| `registry.auth.roles.readonly` | `apicurio.auth.roles.readonly` | Namespace change |
| `registry.auth.role-based-authorization` | `apicurio.auth.role-based-authorization` | Namespace change |
| `registry.auth.owner-only-authorization` | `apicurio.auth.owner-only-authorization` | Namespace change |
| `registry.auth.anonymous-read-access.enabled` | `apicurio.auth.anonymous-read-access.enabled` | Namespace change |

#### Storage Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `quarkus.datasource.db-kind` | `apicurio.storage.sql.kind` | Moved to Apicurio namespace |
| `quarkus.datasource.jdbc.url` | `apicurio.datasource.url` | Simplified property name |
| `quarkus.datasource.username` | `apicurio.datasource.username` | Namespace change |
| `quarkus.datasource.password` | `apicurio.datasource.password` | Namespace change |
| `registry.storage.kind` | `apicurio.storage.kind` | Namespace change |
| `registry.sql.init` | `apicurio.sql.init` | Namespace change |

#### KafkaSQL Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.kafkasql.bootstrap.servers` | `apicurio.kafkasql.bootstrap.servers` | Namespace change |
| `registry.kafkasql.topic` | `apicurio.kafkasql.topic` | Namespace change |
| `registry.kafkasql.security.*` | `apicurio.kafkasql.security.*` | Namespace change |

#### UI Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.ui.features.readOnly` | `apicurio.ui.features.read-only.enabled` | Property restructured |
| `registry.ui.config.uiContextPath` | `apicurio.ui.contextPath` | Simplified |
| `registry.ui.config.apiUrl` | *Removed* | No longer needed |
| `registry.ui.config.auth.type` | *Removed* | No longer needed |
| `registry.ui.root` | *Removed* | No longer needed |

#### REST API Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.rest.artifact.deletion.enabled` | `apicurio.rest.deletion.artifact-version.enabled` | Split into 3 properties |
| N/A | `apicurio.rest.deletion.group.enabled` | New in 3.x |
| N/A | `apicurio.rest.deletion.artifact.enabled` | New in 3.x |
| `registry.rest.artifact.download.maxSize` | `apicurio.rest.artifact.download.max-size.bytes` | Renamed |
| `registry.rest.artifact.download.skipSSLValidation` | `apicurio.rest.artifact.download.ssl-validation.disabled` | Renamed |

#### Limits Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.limits.config.max-artifacts` | `apicurio.limits.config.max-artifacts` | Namespace change |
| `registry.limits.config.max-schema-size-bytes` | `apicurio.limits.config.max-schema-size.bytes` | Renamed |
| `registry.limits.config.max-label-size` | `apicurio.limits.config.max-label-size.bytes` | Renamed |

#### Health Check Configuration Changes

| 2.6.x Property | 3.1.x Property | Notes |
|----------------|----------------|-------|
| `registry.metrics.PersistenceExceptionLivenessCheck.errorThreshold` | `apicurio.metrics.persistence-exception-liveness-check.error-threshold` | Kebab-case |
| `registry.metrics.ResponseErrorLivenessCheck.errorThreshold` | `apicurio.metrics.response-error-liveness-check.error-threshold` | Kebab-case |
| `registry.metrics.PersistenceTimeoutReadinessCheck.timeoutSec` | `apicurio.metrics.persistence-timeout-readiness-check.timeout.seconds` | Kebab-case |

---

## Migration Testing Recommendations

### Pre-Migration Testing

#### 1. Configuration Validation

**Objective**: Ensure all 2.6.x configuration properties are correctly mapped to 3.1.x equivalents.

**Test Cases:**

1. **Create Configuration Mapping Document**
   - List all active configuration properties in 2.6.x deployment
   - Map each to its 3.1.x equivalent using the reference tables above
   - Identify properties that have been removed
   - Plan alternatives for removed features (e.g., multitenancy)

2. **Test Configuration in Staging**
   - Deploy 3.1.x in staging environment with new configuration
   - Verify all services start successfully
   - Check logs for configuration warnings or errors
   - Validate health endpoints respond correctly

3. **Authentication Configuration Testing**
   - Test OIDC authentication flow
   - Verify token validation works
   - Test role-based access control
   - Validate admin override functionality
   - Test basic auth client credentials (if used)

4. **Storage Configuration Testing**
   - Test database connectivity
   - Verify connection pooling settings
   - Test KafkaSQL connectivity (if used)
   - Validate storage backend performs correctly

#### 2. API Compatibility Testing

**Objective**: Ensure existing client applications can work with 3.1.x using the v2 backward compatibility API.

**Test Cases:**

1. **v2 API Backward Compatibility**
   - Test all v2 API operations against 3.1.x
   - Verify artifact creation works
   - Test artifact retrieval
   - Validate version management
   - Test search operations
   - Verify metadata operations
   - Test rule management

2. **Client Application Testing**
   - Run existing client applications against 3.1.x v2 API
   - Verify no breaking changes
   - Test SerDes operations (Avro, Protobuf, JSON)
   - Validate schema validation
   - Test content references

3. **Performance Comparison**
   - Benchmark v2 API operations on 2.6.x
   - Benchmark same operations on 3.1.x v2 API
   - Compare latency and throughput
   - Identify any performance regressions

#### 3. Data Export/Import Testing

**Objective**: Validate the export/import process works correctly and preserves all data.

**Test Cases:**

1. **Export Validation**
   - Export data from 2.6.x test environment
   - Verify export file is created successfully
   - Check export file size is reasonable
   - Extract ZIP and inspect contents
   - Verify JSON structure is valid

2. **Import Validation**
   - Import export file into 3.1.x test environment
   - Verify import completes without errors
   - Check import logs for warnings

3. **Data Integrity Validation**
   - Compare artifact counts (2.6.x vs 3.1.x)
   - Verify all artifact IDs match
   - Check all version global IDs are preserved
   - Validate metadata (names, descriptions, labels, properties)
   - Verify artifact references are intact
   - Check global rules are preserved
   - Validate artifact-specific rules
   - Test content retrieval by hash

4. **Large Dataset Testing**
   - Test export/import with large number of artifacts (10k+)
   - Measure export time
   - Measure import time
   - Monitor memory usage during import
   - Verify no data loss with large datasets

5. **Edge Case Testing**
   - Test artifacts with many versions (100+)
   - Test artifacts with complex references
   - Test artifacts with maximum metadata size
   - Test special characters in artifact names/descriptions
   - Test very large artifact content

### Migration Testing Areas

#### 1. Configuration Testing

**Test Plan:**

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| ENV-001 | Deploy 3.1.x with all converted environment variables | Deployment successful, no errors |
| ENV-002 | Verify authentication configuration | OIDC authentication works correctly |
| ENV-003 | Test RBAC configuration | Roles are enforced correctly |
| ENV-004 | Validate storage backend connectivity | Database/Kafka connection successful |
| ENV-005 | Test health check endpoints | `/health/live` and `/health/ready` return 200 |
| ENV-006 | Verify metrics collection | Prometheus metrics available |
| ENV-007 | Test CORS configuration | CORS headers present in responses |
| ENV-008 | Validate URL override for proxies | External URLs generated correctly |

#### 2. Data Migration Testing

**Test Plan:**

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| DATA-001 | Export all artifacts from 2.6.x | Export file created successfully |
| DATA-002 | Import into empty 3.1.x instance | Import completes without errors |
| DATA-003 | Compare artifact counts | Counts match exactly |
| DATA-004 | Validate artifact metadata | All metadata preserved |
| DATA-005 | Check version preservation | All versions present with correct globalIds |
| DATA-006 | Verify global rules | All global rules migrated |
| DATA-007 | Validate artifact rules | Artifact-specific rules preserved |
| DATA-008 | Test artifact references | References intact and working |
| DATA-009 | Verify content hashes | Content retrievable by hash |
| DATA-010 | Check version comments | Comments migrated correctly |

#### 3. REST API Testing

##### v2 API (Backward Compatibility) Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| API2-001 | Create artifact via v2 API | Artifact created successfully |
| API2-002 | Retrieve artifact via v2 API | Artifact content returned |
| API2-003 | Update artifact via v2 API | New version created |
| API2-004 | Delete artifact via v2 API | Artifact deleted |
| API2-005 | Search artifacts via v2 API | Search results correct |
| API2-006 | Manage metadata via v2 API | Metadata updated |
| API2-007 | Manage rules via v2 API | Rules created/updated/deleted |
| API2-008 | Test artifact updates via v2 API | Validation works correctly |
| API2-009 | Retrieve by globalId via v2 API | Content returned |
| API2-010 | Retrieve by contentHash via v2 API | Content returned |

##### v3 API (New Features) Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| API3-001 | Create empty artifact | Artifact created without versions |
| API3-002 | Create artifact version | Version added to empty artifact |
| API3-003 | Create branch | Branch created successfully |
| API3-004 | List branches | All branches returned |
| API3-005 | Manage branch metadata | Metadata updated |
| API3-006 | Use dryRun parameter | Validation performed without persisting |
| API3-007 | Use references parameter | References handled correctly |
| API3-008 | Search groups | Group search works |
| API3-009 | Search versions | Version search works |
| API3-010 | Manage group metadata | Group metadata updated |

#### 4. Client Application Testing

**Test Plan:**

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| CLIENT-001 | Kafka producer with Avro SerDes | Messages produced successfully |
| CLIENT-002 | Kafka consumer with Avro SerDes | Messages consumed and deserialized |
| CLIENT-003 | Schema validation on produce | Invalid schemas rejected |
| CLIENT-004 | Schema evolution | Compatible changes accepted |
| CLIENT-005 | Protobuf SerDes | Protobuf messages work correctly |
| CLIENT-006 | JSON Schema SerDes | JSON messages validated |
| CLIENT-007 | Registry client SDK operations | All SDK operations work |
| CLIENT-008 | Content references | Referenced schemas resolved |
| CLIENT-009 | Schema caching | Caching improves performance |
| CLIENT-010 | Error handling | Errors handled gracefully |

#### 5. Storage Backend Testing

**Test Plan:**

##### PostgreSQL Storage

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| SQL-001 | Deploy with PostgreSQL | Deployment successful |
| SQL-002 | Initialize database schema | Schema created correctly |
| SQL-003 | Create artifacts | Data persisted to PostgreSQL |
| SQL-004 | Connection pool behavior | Pool manages connections correctly |
| SQL-005 | Database backup/restore | Data recoverable from backup |
| SQL-006 | Transaction handling | ACID properties maintained |
| SQL-007 | Concurrent operations | No deadlocks or conflicts |

##### KafkaSQL Storage

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| KAFKA-001 | Deploy with KafkaSQL | Deployment successful |
| KAFKA-002 | Kafka topic creation | Topics created automatically |
| KAFKA-003 | Data persistence to Kafka | Events published to journal topic |
| KAFKA-004 | Snapshot creation | Snapshots created periodically |
| KAFKA-005 | Recovery from snapshot | Fast startup from snapshot |
| KAFKA-006 | Kafka security (SSL/SASL) | Authentication works |
| KAFKA-007 | Multiple replicas | Replicas stay in sync |

#### 6. Authentication/Authorization Testing

**Test Plan:**

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| AUTH-001 | OIDC authentication flow | Users authenticated via OIDC |
| AUTH-002 | JWT token validation | Tokens validated correctly |
| AUTH-003 | Role-based access (admin) | Admin role has full access |
| AUTH-004 | Role-based access (developer) | Developer role limited correctly |
| AUTH-005 | Role-based access (readonly) | Readonly role cannot modify |
| AUTH-006 | Owner-only authorization | Only owners can modify artifacts |
| AUTH-007 | Admin override | Admin can override ownership |
| AUTH-008 | Anonymous read access | Unauthenticated users can read |
| AUTH-009 | Authenticated read access | Authenticated users can read |
| AUTH-010 | Basic auth client credentials | Basic auth works for clients |
| AUTH-011 | Token expiration handling | Expired tokens rejected |
| AUTH-012 | Invalid tokens | Invalid tokens rejected |

### Regression Testing Suite

#### Automated Test Scenarios

##### 1. Artifact Lifecycle Tests

```gherkin
Feature: Artifact Lifecycle

  Scenario: Create and manage artifact versions
    Given I am authenticated as a developer
    When I create an artifact "com.example.MySchema" in group "default"
    And I create version "1.0.0" with Avro schema
    And I create version "1.1.0" with compatible Avro schema
    And I create version "2.0.0" with breaking Avro schema
    Then the artifact should have 3 versions
    And version "2.0.0" should be the latest
    When I retrieve the artifact
    Then I should get version "2.0.0" content
    When I delete version "2.0.0"
    Then the artifact should have 2 versions
    And version "1.1.0" should be the latest
```

##### 2. Rule Management Tests

```gherkin
Feature: Rule Management

  Scenario: Global compatibility rule enforcement
    Given I am authenticated as an admin
    When I create global rule "COMPATIBILITY" with config "BACKWARD"
    And I create an artifact "com.example.Schema1" with version "1.0.0"
    And I try to create version "1.1.0" with incompatible schema
    Then the operation should fail with compatibility violation
    When I create version "1.1.0" with compatible schema
    Then the operation should succeed

  Scenario: Artifact-specific rules override global rules
    Given I am authenticated as a developer
    And global rule "COMPATIBILITY" is set to "BACKWARD"
    When I create artifact "com.example.Schema2"
    And I create artifact rule "COMPATIBILITY" with config "NONE"
    And I try to create incompatible version
    Then the operation should succeed
```

##### 3. Search Operation Tests

```gherkin
Feature: Search Operations

  Scenario: Search artifacts by name
    Given I have created artifacts with names "Schema1", "Schema2", "MySchema"
    When I search for artifacts with name containing "Schema"
    Then I should get 2 results
    And results should include "Schema1" and "Schema2"

  Scenario: Search artifacts by labels
    Given I have created artifacts with labels:
      | Artifact  | Labels          |
      | Schema1   | env:prod,type:avro |
      | Schema2   | env:dev,type:json  |
      | Schema3   | env:prod,type:json |
    When I search for artifacts with label "env:prod"
    Then I should get 2 results
    And results should include "Schema1" and "Schema3"
```

##### 4. Reference Tests

```gherkin
Feature: Artifact References

  Scenario: Create artifact with references
    Given I have created artifact "AddressSchema" in group "common"
    When I create artifact "PersonSchema" in group "default"
    And I add reference to "common/AddressSchema" version "1.0.0"
    Then the artifact should have 1 reference
    When I retrieve "PersonSchema" with dereference
    Then I should get both "PersonSchema" and "AddressSchema" content

  Scenario: Delete referenced artifact should fail
    Given artifact "PersonSchema" references "AddressSchema"
    When I try to delete "AddressSchema"
    Then the operation should fail with reference constraint
```

##### 5. Content Hash Tests

```gherkin
Feature: Content Hashing and Deduplication

  Scenario: Same content creates only one version
    Given I create artifact "Schema1" with content "ContentA"
    When I try to create new version with same content "ContentA"
    Then no new version should be created
    And I should get reference to existing version

  Scenario: Retrieve content by hash
    Given I create artifact with content "ContentA"
    And the content hash is "abc123..."
    When I retrieve content by hash "abc123..."
    Then I should get "ContentA"
```

### Integration Test Framework

#### Test Environment Setup

```yaml
# docker-compose.test.yml
version: '3.8'
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: registry
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    ports:
      - "8090:8080"
    command: start-dev

  apicurio-registry:
    image: apicurio/apicurio-registry:3.1.x
    environment:
      APICURIO_STORAGE_KIND: sql
      APICURIO_STORAGE_SQL_KIND: postgresql
      APICURIO_DATASOURCE_URL: jdbc:postgresql://postgres:5432/registry
      APICURIO_DATASOURCE_USERNAME: postgres
      APICURIO_DATASOURCE_PASSWORD: postgres
      QUARKUS_OIDC_TENANT_ENABLED: true
      QUARKUS_OIDC_AUTH_SERVER_URL: http://keycloak:8080/realms/registry
      QUARKUS_OIDC_CLIENT_ID: registry-api
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - keycloak
```

#### Test Execution Strategy

1. **Unit Tests**
   - Test individual API operations
   - Mock external dependencies
   - Fast execution (< 1 minute)

2. **Integration Tests**
   - Test against real database
   - Test against real Keycloak
   - Medium execution time (5-10 minutes)

3. **End-to-End Tests**
   - Test complete workflows
   - Test client applications
   - Longer execution time (15-30 minutes)

4. **Performance Tests**
   - Load testing
   - Stress testing
   - Endurance testing
   - Variable execution time (30 minutes - hours)

### Migration Rollback Testing

#### Rollback Scenarios

1. **Immediate Rollback** (within hours of migration)
   - DNS switch back to 2.6.x
   - Verify 2.6.x still operational
   - Test client applications work
   - Verify no data created in 3.1.x during brief period

2. **Delayed Rollback** (days after migration)
   - Export data from 3.1.x
   - Identify new artifacts created in 3.1.x
   - Import new artifacts into 2.6.x (if possible)
   - DNS switch back to 2.6.x
   - Validate data integrity

3. **Partial Rollback** (some clients stay on 3.1.x)
   - Keep both 2.6.x and 3.1.x running
   - Use different DNS names
   - Sync data between instances
   - Gradually re-migrate to 3.1.x

### Continuous Testing Strategy

#### Pre-Production Testing

```yaml
# CI/CD Pipeline Stages
stages:
  - build
  - unit-test
  - integration-test
  - migration-test
  - performance-test
  - deploy-staging
  - e2e-test
  - deploy-production

migration-test:
  stage: migration-test
  script:
    - ./scripts/setup-registry-2.6.sh
    - ./scripts/populate-test-data.sh
    - ./scripts/export-from-2.6.sh
    - ./scripts/setup-registry-3.1.sh
    - ./scripts/import-to-3.1.sh
    - ./scripts/validate-migration.sh
  artifacts:
    paths:
      - migration-report.html
    when: always
```

#### Monitoring During Migration

**Key Metrics to Monitor:**

1. **Application Metrics**
   - Request rate
   - Error rate
   - Response time (p50, p95, p99)
   - Active connections

2. **Infrastructure Metrics**
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network I/O

3. **Database Metrics**
   - Connection pool usage
   - Query execution time
   - Transaction rate
   - Deadlocks

4. **Business Metrics**
   - Total artifacts
   - Total versions
   - Daily artifact creations
   - Daily version creations

---

## References

### Official Documentation

1. **Apicurio Registry 3.0 Migration Guide**
   - URL: https://www.apicur.io/blog/2025/03/30/migrate-registry-2-to-3
   - Key Topics: Breaking changes, data model changes, migration steps

2. **Apicurio Registry 3.0 Configuration Migration**
   - URL: https://www.apicur.io/blog/2025/04/02/application-configuration-migration
   - Key Topics: Property renaming, configuration changes

3. **Red Hat Migration Guide**
   - URL: https://docs.redhat.com/en/documentation/red_hat_build_of_apicurio_registry/3.1/html-single/migrating_apicurio_registry_deployments/
   - Key Topics: Enterprise migration procedures

4. **Apicurio Registry Documentation**
   - URL: https://www.apicur.io/registry/docs/apicurio-registry/3.0.x/getting-started/assembly-migrating-registry-v2-v3.html
   - Key Topics: Migration assembly guide

### Source Code Repositories

1. **Apicurio Registry 2.6.x**
   - Repository: git@github.com:Apicurio/apicurio-registry.git
   - Branch: 2.6.x
   - Local Path: `/home/ewittman/git/apicurio/apicurio-testing/.work/apicurio-registry-2.6`

2. **Apicurio Registry 3.1.x**
   - Repository: git@github.com:Apicurio/apicurio-registry.git
   - Branch: main
   - Local Path: `/home/ewittman/git/apicurio/apicurio-testing/.work/.work/apicurio-registry-3.1`

### API Specifications

1. **Registry 2.6.x API (v2)**
   - Path: `apicurio-registry-2.6/common/src/main/resources/META-INF/openapi.json`
   - Base Path: `/apis/registry/v2`

2. **Registry 3.1.x API (v2 - deprecated)**
   - Path:
     `apicurio-registry-3.1/app/src/main/resources-unfiltered/META-INF/resources/api-specifications/registry/v2/openapi.json`
   - Base Path: `/apis/registry/v2`

3. **Registry 3.1.x API (v3)**
   - Path:
     `apicurio-registry-3.1/app/src/main/resources-unfiltered/META-INF/resources/api-specifications/registry/v3/openapi.json`
   - Base Path: `/apis/registry/v3`

4. **Confluent Compatibility API (v7)**
   - Path:
     `apicurio-registry-3.1/app/src/main/resources-unfiltered/META-INF/resources/api-specifications/ccompat/v7/openapi.json`

5. **GitOps API (v0)**
   - Path:
     `apicurio-registry-3.1/app/src/main/resources-unfiltered/META-INF/resources/api-specifications/gitops/v0/openapi.json`

### Configuration References

1. **Registry 2.6.x Configuration**
   - Path: `apicurio-registry-2.6/docs/modules/ROOT/partials/getting-started/ref-registry-all-configs.adoc`

2. **Registry 3.1.x Configuration**
   - Path: `apicurio-registry-3.1/docs/modules/ROOT/partials/getting-started/ref-registry-all-configs.adoc`

---

## Appendix: Quick Reference Cards

### Migration Checklist

```
□ Pre-Migration
  □ Review current 2.6.x configuration
  □ Map all properties to 3.1.x equivalents
  □ Test export from 2.6.x non-production environment
  □ Set up 3.1.x test environment
  □ Test import into 3.1.x
  □ Validate data integrity
  □ Test client applications against 3.1.x

□ Migration Day
  □ Announce maintenance window
  □ Stop writes to 2.6.x (read-only mode if possible)
  □ Export final data from 2.6.x production
  □ Verify export file integrity
  □ Deploy 3.1.x to production
  □ Import data into 3.1.x
  □ Validate artifact count matches
  □ Verify global rules
  □ Test sample artifacts
  □ Switch DNS/routing to 3.1.x
  □ Monitor for errors
  □ Validate client applications

□ Post-Migration
  □ Monitor metrics and logs
  □ Verify no errors in client applications
  □ Keep 2.6.x running for rollback (1-2 weeks)
  □ Update all client applications to use v3 API (gradual)
  □ Document lessons learned
  □ Decommission 2.6.x after successful migration
```

### Common Migration Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Configuration property not recognized | Warning in logs | Check property name mapping table |
| Authentication failure | 401 errors | Verify OIDC configuration, check client credentials |
| Database connection failure | Registry won't start | Verify datasource URL, username, password |
| Import fails | Error during import | Check export file format, ensure registry is empty |
| Missing artifacts after import | Count mismatch | Re-run import, check for errors in import logs |
| Client application errors | Serialization errors | Update client libraries to 3.x, update registry URL |
| Performance degradation | Slow responses | Check database connection pool, review resource limits |

### Emergency Rollback Procedure

```bash
# 1. Switch DNS/Load Balancer back to 2.6.x
# (Specific steps depend on your infrastructure)

# 2. Verify 2.6.x is operational
curl http://registry-2.6.example.com/apis/registry/v2/system/info

# 3. Verify artifact count
curl http://registry-2.6.example.com/apis/registry/v2/search/artifacts?limit=1

# 4. Test client application connectivity
# (Run smoke tests against 2.6.x)

# 5. Announce rollback to stakeholders

# 6. Investigate issues with 3.1.x migration

# 7. Plan re-migration after issues resolved
```

---

**End of Analysis Document**
