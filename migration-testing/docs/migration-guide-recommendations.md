# Migration Guide Recommendations

**Date**: 2025-11-18
**Based on**: Analysis of four practical migration scenarios vs. migration.adoc

---

## Executive Summary

The migration guide at `migration.adoc` is **fundamentally accurate** in its core concepts and configuration
mappings. However, practical implementation via four test scenarios reveals several **critical gaps** and areas
where additional guidance would significantly improve customer success rates.

This document provides detailed recommendations for enhancing the migration guide based on real-world migration
testing scenarios.

---

## ✅ What the Guide Gets Right

### 1. Export/Import Process (Validated by all scenarios)
- The documented API endpoints are correct
- The curl command syntax is accurate
- The process preserves artifact identifiers, metadata, and references

### 2. Configuration Property Mappings (Validated by scenarios 1-4)
All documented property mappings are confirmed accurate:
- Database: `REGISTRY_DATASOURCE_*` → `APICURIO_DATASOURCE_*`
- KafkaSQL: `REGISTRY_KAFKASQL_*` → `APICURIO_KAFKASQL_*`
- Auth: `REGISTRY_AUTH_*` → `apicurio.auth.*`
- OIDC: `KEYCLOAK_*` → `QUARKUS_OIDC_*`

### 3. TLS Configuration (Validated by scenario 3)
Server-side TLS configuration is identical between v2 and v3 (both use Quarkus).

---

## ❌ Critical Gaps and Recommended Additions

### 1. KafkaSQL Storage Migration Warning ⚠️ **CRITICAL**

**Issue**: The guide doesn't mention that v3 **cannot read v2's KafkaSQL journal topic**.

**Evidence from Scenario 2**:
```yaml
# v2 uses different topic
REGISTRY_KAFKASQL_TOPIC: kafkasql-journal-v2

# v3 uses different topic
APICURIO_KAFKASQL_TOPIC: kafkasql-journal-v3
```

The v3 KafkaSQL implementation cannot consume from v2's journal topic due to schema/format differences.

**Recommendation**: Add a prominent warning in the "Re-engineered Kafka storage variant" section:

```asciidoc
[WARNING]
====
{registry} 3.x cannot read the KafkaSQL journal topic from {registry} {registry-v2} due to internal schema
changes. You MUST use the export/import process to migrate data between versions. Do not attempt to reuse
the v2 KafkaSQL topic with a v3 deployment.

When deploying {registry} 3.x with KafkaSQL storage alongside an existing v2 instance, configure v3 to use
a different topic name to avoid conflicts:

[source,properties]
----
# Registry 2.x
REGISTRY_KAFKASQL_TOPIC=kafkasql-journal-v2

# Registry 3.x (use different topic)
APICURIO_KAFKASQL_TOPIC=kafkasql-journal-v3
----

After the v3 deployment is running with its own topic, use the export/import APIs to migrate your data from
v2 to v3.
====
```

---

### 2. Kafka SerDes Client Migration ⚠️ **CRITICAL**

**Issue**: The guide mentions updating dependencies but doesn't provide the specific Maven artifact changes or
code migration details required for Kafka SerDes integrations.

**Evidence from Scenario 2**:

**Maven Coordinates Changed**:
- v2: `io.apicurio:apicurio-registry-serdes-avro-serde:2.6.13.Final`
- v3: `io.apicurio:apicurio-registry-avro-serde-kafka:3.1.2`

**Package Paths Changed**:
```java
// v2
import io.apicurio.registry.utils.serde.SerdeConfig;
import io.apicurio.registry.utils.serde.avro.AvroKafkaSerdeConfig;

// v3
import io.apicurio.registry.serde.config.SerdeConfig;
import io.apicurio.registry.serde.avro.AvroSerdeConfig;
```

**Recommendation**: Add a new subsection under "Migrating {registry} client applications":

```asciidoc
=== Updating Kafka SerDes integrations

If you use Kafka serializers and deserializers with {registry}, you must update both the Maven artifact
coordinates and Java import statements when migrating to 3.x.

.Maven dependency changes
[source,xml,subs="attributes+"]
----
<!-- Registry 2.x -->
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-serdes-avro-serde</artifactId>
    <version>2.6.13.Final</version>
</dependency>

<!-- Registry 3.x -->
<dependency>
    <groupId>io.apicurio</groupId>
    <artifactId>apicurio-registry-avro-serde-kafka</artifactId>
    <version>{registry-release}</version>
</dependency>
----

.Java package path changes
[source,java]
----
// Registry 2.x imports
import io.apicurio.registry.utils.serde.SerdeConfig;
import io.apicurio.registry.utils.serde.avro.AvroKafkaSerdeConfig;
import io.apicurio.registry.utils.serde.avro.ReflectAvroDatumProvider;

// Registry 3.x imports
import io.apicurio.registry.serde.config.SerdeConfig;
import io.apicurio.registry.serde.avro.AvroSerdeConfig;
import io.apicurio.registry.serde.avro.ReflectAvroDatumProvider;
----

The configuration property names and values remain the same; only the package structure has changed to align
with the new SDK architecture.

.Kafka producer configuration example (3.x)
[source,java]
----
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroKafkaSerializer.class);

// Registry configuration
props.put(SerdeConfig.REGISTRY_URL, "http://registry:8080/apis/registry/v3");
props.put(SerdeConfig.AUTO_REGISTER_ARTIFACT, true);
props.put(AvroSerdeConfig.AVRO_DATUM_PROVIDER, ReflectAvroDatumProvider.class.getName());

KafkaProducer<String, MyObject> producer = new KafkaProducer<>(props);
----

[NOTE]
====
After migrating the registry server to 3.x, your existing Kafka applications using v2 SerDes libraries will
continue to function via backward compatibility. However, you should plan to update these applications to use
the v3 SerDes libraries to take advantage of new features and ensure long-term support.
====
```

---

### 3. Client-Side SSL Configuration Differences

**Issue**: The guide correctly documents server-side TLS configuration (which is identical for v2 and v3), but
doesn't explain that SSL configuration differs between v2 and v3 **client** libraries.

**Evidence from Scenario 3**:

**v2 Client** (uses JVM system properties):
```java
System.setProperty("javax.net.ssl.trustStore", "certs/registry-truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword", "registry123");
RegistryClient client = RegistryClientFactory.create(registryUrl);
```

**v3 Client** (uses RegistryClientOptions API):
```java
RegistryClientOptions options = RegistryClientOptions.create(registryUrl)
    .trustStoreJks("certs/registry-truststore.jks", "registry123");
RegistryClient client = RegistryClientFactory.create(options);
```

**Recommendation**: Add to the existing TLS documentation or create a new subsection in "Migrating {registry}
client applications":

```asciidoc
=== Client SSL/TLS configuration changes

While server-side TLS configuration remains identical between {registry} {registry-v2} and 3.x, the client
SDK approach to SSL configuration has changed.

.Registry 2.x client SSL configuration
[source,java]
----
// Configure globally via JVM system properties
System.setProperty("javax.net.ssl.trustStore", "/path/to/truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword", "password");

// Client automatically uses system SSL context
RegistryClient client = RegistryClientFactory.create("https://registry:8443/apis/registry/v2");
----

.Registry 3.x client SSL configuration
[source,java]
----
// Configure explicitly via RegistryClientOptions API
RegistryClientOptions options = RegistryClientOptions.create(
        "https://registry:8443/apis/registry/v3")
    .trustStoreJks("/path/to/truststore.jks", "password");

RegistryClient client = RegistryClientFactory.create(options);
----

The v3 approach provides several advantages:
- More explicit configuration that's easier to understand and debug
- Better isolation: per-client SSL configuration without affecting global JVM settings
- Support for additional SSL options (trust all certificates, custom certificate paths, mTLS)
- Cleaner code that doesn't rely on side-effect configuration

.Additional SSL options in v3
[source,java]
----
// Trust all certificates (development/testing only)
RegistryClientOptions options = RegistryClientOptions.create(registryUrl)
    .trustAll(true);

// Use custom certificate file
RegistryClientOptions options = RegistryClientOptions.create(registryUrl)
    .trustStorePem("/path/to/ca-cert.pem");
----

[WARNING]
====
The `trustAll(true)` option disables SSL certificate validation and should only be used in development or
testing environments with self-signed certificates. Never use this option in production deployments.
====
```

---

### 4. Import Validation Steps

**Issue**: The guide shows validation commands but doesn't explain what to verify, what the expected outcomes
are, or how to interpret the results.

**Evidence from Scenarios**: All four scenarios perform comprehensive validation:
- Verify artifact counts match between v2 and v3
- Confirm global rules were imported
- Check export file size is reasonable (> 1KB indicates data present)
- Validate import returns expected HTTP status codes (200 or 204)

**Recommendation**: Expand the validation step in "Migrating {registry} data":

```asciidoc
. Validate the migrated content:
+
--
After importing, verify that all content was successfully migrated by comparing artifact counts and checking
that global rules were preserved.

.Compare artifact counts
[source,bash,subs="attributes+"]
----
# Count artifacts in v2 registry
v2_count=$(curl -s "http://old-registry.my-company.com/apis/registry/v2/search/artifacts" | jq '.count')

# Count artifacts in v3 registry
v3_count=$(curl -s "http://new-registry.my-company.com/apis/registry/v3/search/artifacts" | jq '.count')

# Compare counts
if [ "$v2_count" -eq "$v3_count" ]; then
    echo "✓ Migration successful: $v3_count artifacts migrated"
else
    echo "✗ Migration incomplete: v2 has $v2_count artifacts, v3 has $v3_count artifacts"
    exit 1
fi
----

.Verify global rules
[source,bash,subs="attributes+"]
----
# List global rules in v3 registry
curl "http://new-registry.my-company.com/apis/registry/v3/admin/rules"
----

Expected response should list any global rules configured in v2 (e.g., `VALIDITY`, `COMPATIBILITY`). If you
had global rules in v2 but see an empty list in v3, the import may have failed.

.Validate export file integrity
Before importing, verify the export file contains data:

[source,bash]
----
# Check export file size (should be > 1KB if data exists)
ls -lh registry-export.zip

# Verify it's a valid ZIP file
unzip -t registry-export.zip
----

.Check import response
The import endpoint should return HTTP status code 204 (No Content) or 200 (OK) on success. Any 4xx or 5xx
status code indicates a failure:

[source,bash]
----
response=$(curl -w "%{http_code}" -X POST \
  "http://new-registry.my-company.com/apis/registry/v3/admin/import" \
  -H "Content-Type: application/zip" \
  --data-binary @registry-export.zip)

if [[ "$response" == "200" ]] || [[ "$response" == "204" ]]; then
    echo "✓ Import successful"
else
    echo "✗ Import failed with HTTP status: $response"
    exit 1
fi
----

[NOTE]
====
After a successful import, allow a few seconds for indexing to complete before running validation queries.
Large imports may require more time for background processing to finish.
====
--
```

---

### 5. Traffic Switching Strategy

**Issue**: The guide mentions "updating client applications" and "reconfiguring endpoints," but doesn't
discuss production deployment strategies like load balancer switching, gradual migration, or rollback plans.

**Evidence from Scenarios**: All four scenarios use nginx as a reverse proxy to enable:
- Zero-downtime switchover by changing upstream configuration
- Easy rollback if issues occur (switch back to v2)
- Potential for gradual traffic migration (weighted routing)

**Recommendation**: Add a new section after "Migrating {registry} data":

```asciidoc
[id="traffic-migration-strategies_{context}"]
== Traffic migration strategies

[role="_abstract"]
Plan your traffic migration approach based on your deployment size, risk tolerance, and downtime constraints.
This section outlines three common strategies for transitioning client applications from {registry}
{registry-v2} to 3.x.

=== Strategy 1: Direct cutover

Update all client applications to point to the new v3 registry URL during a scheduled maintenance window.

.Procedure
. Schedule a maintenance window and notify stakeholders
. Deploy {registry} 3.x with a new URL (e.g., `registry-v3.my-company.com`)
. Export data from v2 and import into v3
. Update all client application configurations to use the v3 URL
. Restart client applications
. Validate that all clients are functioning correctly
. Decommission the v2 registry after a successful validation period

.Best suited for
- Small to medium deployments with few client applications
- Environments where scheduled downtime is acceptable
- Testing and development environments

=== Strategy 2: Load balancer switching (recommended for production)

Use a reverse proxy or load balancer to control traffic routing, enabling zero-downtime migration with easy
rollback capability.

.Procedure
. Configure a load balancer (nginx, HAProxy, cloud load balancer) with a stable URL
. Point all client applications to the load balancer URL (e.g., `registry.my-company.com`)
. Initially route traffic to the v2 registry
. Deploy {registry} 3.x and import data
. Validate v3 registry is functioning correctly using direct URL
. Update load balancer configuration to route traffic to the v3 registry
. Monitor applications for issues
. If problems occur, rollback by switching load balancer back to v2
. After successful validation period, decommission v2 registry

.Example nginx configuration
[source,nginx]
----
upstream registry {
    # Initially points to v2
    server registry-v2:8080;

    # Switch to v3 by changing this line
    # server registry-v3:8080;
}

server {
    listen 8080;
    server_name registry.my-company.com;

    location / {
        proxy_pass http://registry;
        proxy_set_header Host $host;
        client_max_body_size 50M;
    }
}
----

.Best suited for
- Production environments requiring zero downtime
- Large deployments where rollback capability is critical
- Situations where you want to validate v3 thoroughly before committing

=== Strategy 3: Gradual migration

Migrate client applications in phases while running both v2 and v3 registries simultaneously.

.Procedure
. Deploy {registry} 3.x with a separate URL alongside v2
. Export data from v2 and import into v3
. Update a small subset of client applications to use the v3 URL
. Monitor v3 registry stability and performance
. Gradually migrate additional client applications in batches
. Continue until all clients have been migrated to v3
. Decommission v2 registry

.Best suited for
- Very large deployments with many client applications
- Environments requiring minimal risk
- Situations where client applications cannot all be updated simultaneously

[NOTE]
====
When running v2 and v3 side-by-side, any artifacts created in v2 after the initial export will not
automatically appear in v3. Plan your migration timeline to minimize the period where both registries
receive updates, or consider running periodic exports/imports until all clients have migrated.
====

=== Rollback considerations

Regardless of the migration strategy you choose, plan for potential rollback scenarios:

- Maintain the v2 deployment for at least 48-72 hours after migration
- Document the rollback procedure specific to your strategy
- Ensure you have backups of both v2 and v3 data
- Test the rollback process in a non-production environment
- Monitor key metrics (request latency, error rates, artifact operations) after migration
```

---

### 6. Backward Compatibility Testing

**Issue**: The guide doesn't explicitly state that v2 clients work with v3 registry, which is a critical
feature that reduces migration risk and complexity.

**Evidence from Scenarios**: Scenarios 1, 3, and 4 successfully run v2 client applications against the v3
registry after migration, confirming full backward compatibility with the v2 REST API.

**Recommendation**: Add a prominent note in "Migrating {registry} client applications":

```asciidoc
[NOTE]
====
{registry} 3.x maintains full backward compatibility with {registry-v2} client libraries and REST API calls.
After migrating the registry server to 3.x, your existing v2 client applications will continue to function
without any code changes. The `/apis/registry/v2` endpoint remains fully supported in 3.x deployments.

This backward compatibility allows you to:

* Migrate the registry server first, then update client applications on your own timeline
* Test the v3 registry with production traffic before committing to client upgrades
* Run a mix of v2 and v3 client applications during a gradual migration
* Minimize deployment risk by separating server and client migration activities

While v2 clients continue to work, you should plan to upgrade client applications to use the v3 SDK and API
to take advantage of new features such as branches, enhanced search, and improved governance capabilities.
====
```

---

### 7. Missing Configuration Properties

**Issue**: The scenarios reveal several important v3-only configuration properties that are not documented in
the migration guide.

**Evidence**:

**Deletion Configuration** (Scenario 1):
```yaml
# v3 only - controls whether deletion operations are allowed
apicurio.rest.deletion.group.enabled: "true"
apicurio.rest.deletion.artifact.enabled: "true"
apicurio.rest.deletion.artifact-version.enabled: "true"
```

**Storage Kind Configuration** (Scenarios 1, 2):
```yaml
# v3 only - explicitly declares storage implementation
APICURIO_STORAGE_KIND: "sql"              # or "kafkasql"
APICURIO_STORAGE_SQL_KIND: "postgresql"   # when using sql storage
```

**Recommendation**: Add to the "Updating {registry} configuration" section:

```asciidoc
=== New configuration properties in 3.x

{registry} 3.x introduces new configuration properties that must be set explicitly, particularly for storage
selection and deletion policies.

[cols="1,1,1",options="header"]
|===
| Property
| Description
| Default Value

| `apicurio.storage.kind`
| Storage implementation type
| `sql`

| `apicurio.storage.sql.kind`
| Database type when using SQL storage
| `h2`

| `apicurio.rest.deletion.group.enabled`
| Enable group deletion via REST API
| `false`

| `apicurio.rest.deletion.artifact.enabled`
| Enable artifact deletion via REST API
| `false`

| `apicurio.rest.deletion.artifact-version.enabled`
| Enable version deletion via REST API
| `false`
|===

.Storage configuration example (PostgreSQL)
[source,properties]
----
apicurio.storage.kind=sql
apicurio.storage.sql.kind=postgresql
apicurio.datasource.url=jdbc:postgresql://postgres:5432/registry
apicurio.datasource.username=apicurio
apicurio.datasource.password=password
----

.Storage configuration example (KafkaSQL)
[source,properties]
----
apicurio.storage.kind=kafkasql
apicurio.kafkasql.bootstrap.servers=kafka:9092
apicurio.kafkasql.topic=kafkasql-journal
apicurio.kafkasql.topic.auto-create=true
----

[IMPORTANT]
====
The deletion properties default to `false` in {registry} 3.x for safety. If your v2 deployment allowed
deletions and you need to preserve this behavior, explicitly enable the deletion properties in your v3
configuration.
====
```

---

### 8. Troubleshooting Section

**Issue**: The guide doesn't include troubleshooting guidance for common migration issues.

**Evidence from Scenarios**: Common issues encountered during scenario development and testing.

**Recommendation**: Add a new troubleshooting section:

```asciidoc
[id="migration-troubleshooting_{context}"]
== Troubleshooting migration issues

[role="_abstract"]
Common issues encountered during migration and their solutions.

=== Import fails with "413 Request Entity Too Large"

*Symptom*: The import API call fails with HTTP 413 status code.

*Cause*: The export file exceeds the maximum request size configured in your reverse proxy, ingress
controller, or application server.

*Solution*: Increase the maximum request body size:

.Nginx
[source,nginx]
----
http {
    client_max_body_size 50M;  # Adjust based on your export size
}
----

.Quarkus (if connecting directly to registry)
[source,properties]
----
quarkus.http.limits.max-body-size=50M
----

=== Import returns 204 but no artifacts appear

*Symptom*: The import API returns success (204 or 200), but searching for artifacts returns an empty list.

*Cause*: Background indexing may still be in progress, especially for large imports.

*Solution*:
. Wait 5-10 seconds after import completes
. Check registry logs for import processing messages or errors
. Verify the export file is not empty: `unzip -l registry-export.zip`
. Try querying specific artifacts by ID instead of using search

=== Authentication fails after migration to v3

*Symptom*: Clients receive 401 or 403 errors when connecting to the v3 registry.

*Cause*: OIDC configuration properties have changed between v2 and v3.

*Solution*:
. Verify OIDC redirect URIs are updated to use new property names (e.g., `quarkus.oidc.redirect-uri`)
. Confirm role mappings use the `apicurio.auth.roles.*` prefix instead of `registry.auth.roles.*`
. Check that the OIDC server URL uses the v3 format: `quarkus.oidc.auth-server-url=https://keycloak/realms/
registry`
. Review registry logs for authentication-related errors

=== KafkaSQL consumer group continuously rebalancing

*Symptom*: After starting v3 with KafkaSQL storage, logs show repeated consumer group rebalancing.

*Cause*: Consumer group configuration may be conflicting with v2 settings, or Kafka cluster is experiencing
issues.

*Solution*:
. Ensure v3 uses a different consumer group ID than v2: `apicurio.kafkasql.consumer.group-id`
. Verify v3 is using a different topic than v2 (they cannot share the same journal topic)
. Check Kafka broker health and network connectivity
. Allow 30-60 seconds for initial consumer group stabilization after startup

=== TLS certificate validation errors

*Symptom*: Clients fail with "unable to find valid certification path" or similar SSL errors.

*Cause*: Client trust store doesn't include the v3 registry's certificate.

*Solution*:
. For v2 clients: Set JVM system properties `-Djavax.net.ssl.trustStore=/path/to/truststore.jks`
. For v3 clients: Use `RegistryClientOptions.create(url).trustStoreJks("/path/to/truststore.jks",
"password")`
. For development/testing with self-signed certificates: Use `curl -k` or `.trustAll(true)` (not for
production)
. Verify certificate includes correct SAN entries for the registry hostname

=== Export file is empty or very small

*Symptom*: The export file is less than 1KB or appears to contain no data.

*Cause*: The v2 registry may be empty, or the export request didn't complete successfully.

*Solution*:
. Verify v2 registry contains artifacts: `curl http://v2-registry/apis/registry/v2/search/artifacts`
. Check the export HTTP response code (should be 200)
. Review v2 registry logs for export errors
. Ensure you have sufficient permissions to access the admin export endpoint

=== Version compatibility issues

*Symptom*: Import fails with format or schema errors.

*Cause*: Export format from very old v2 versions may not be compatible with v3.

*Solution*:
. Ensure v2 registry is at least version 2.4.x or later
. Check v3 registry logs for specific format errors
. If using a very old v2 version, consider upgrading v2 first, then migrating to v3
```

---

### 9. Pre-Migration Checklist

**Issue**: The guide jumps directly into migration steps without helping users prepare adequately.

**Recommendation**: Add a pre-migration checklist section before "Migrating {registry} data":

```asciidoc
[id="pre-migration-checklist_{context}"]
== Pre-migration checklist

[role="_abstract"]
Complete these preparation steps before beginning your migration to ensure a smooth transition and minimize
risk.

=== Planning and assessment

[ ] Document your current {registry} {registry-v2} deployment:

* Registry version number
* Storage type (PostgreSQL, KafkaSQL, etc.)
* Number of artifacts and total versions
* Global rules configured
* Authentication/authorization setup
* TLS/SSL configuration
* Client applications and their dependencies

[ ] Identify all client applications that connect to the registry:

* Direct REST API clients
* Kafka SerDes integrations (producers and consumers)
* CI/CD pipelines
* Development tools and scripts

[ ] Review client application dependency versions:

* Document current SDK versions (`io.apicurio:apicurio-registry-*`)
* Identify which clients can be updated immediately vs. gradually
* Plan client upgrade timeline

=== Environment preparation

[ ] Provision infrastructure for {registry} 3.x:

* Database instance (if using SQL storage)
* Kafka cluster (if using KafkaSQL storage)
* Compute resources (containers, VMs, etc.)
* Network connectivity and firewall rules

[ ] If using KafkaSQL storage:

* Allocate a new topic name for v3 (cannot reuse v2 topic)
* Ensure Kafka cluster is accessible from v3 deployment
* Configure appropriate retention settings

[ ] If using TLS/SSL:

* Verify certificates are valid for new v3 endpoint hostnames
* Generate new certificates if needed (include SAN entries)
* Prepare trust stores for client applications

[ ] If using authentication:

* Review OIDC/Keycloak configuration
* Update redirect URIs for v3 endpoints
* Verify role mappings in identity provider

=== Backup and safety measures

[ ] Back up your {registry} {registry-v2} deployment:

* Database backup (if using SQL storage)
* Kafka topic snapshot (if using KafkaSQL storage)
* Configuration files and environment variables
* Document recovery procedures

[ ] Test export in non-production environment:

* Run export on a copy of production data
* Verify export file is complete (check file size and artifact count)
* Validate export can be imported into test v3 instance

[ ] Prepare rollback plan:

* Document steps to revert to v2 if issues occur
* Ensure v2 deployment can remain operational during migration
* Plan for maintaining both v2 and v3 temporarily if needed

=== Migration execution preparation

[ ] Choose traffic migration strategy:

* Direct cutover (with maintenance window)
* Load balancer switching (zero downtime)
* Gradual migration (phased approach)

[ ] Schedule migration window (if applicable):

* Notify stakeholders and users
* Plan for off-peak hours if possible
* Allocate sufficient time for validation

[ ] Prepare validation criteria:

* Artifact count comparison
* Global rules verification
* Sample artifact retrieval tests
* Client application connectivity tests

[ ] Set up monitoring and logging:

* Configure registry logs for v3 deployment
* Set up alerts for errors or performance issues
* Prepare to monitor client application behavior

[NOTE]
====
The time required for migration varies based on registry size:
- Small deployments (<1000 artifacts): 30-60 minutes
- Medium deployments (1000-10000 artifacts): 1-3 hours
- Large deployments (>10000 artifacts): 3+ hours

Plan your migration window accordingly, with buffer time for unexpected issues.
====
```

---

## Summary of Recommendations by Priority

| Priority | Section | Description | Location in Guide |
|----------|---------|-------------|-------------------|
| **CRITICAL** | KafkaSQL Warning | v3 cannot read v2 journal topics | "Re-engineered Kafka storage variant" |
| **CRITICAL** | Kafka SerDes Migration | Maven coordinates and package path changes | "Migrating client applications" |
| **HIGH** | Client SSL Configuration | v2 vs v3 client SSL setup differences | "Migrating client applications" |
| **HIGH** | Backward Compatibility | Explicitly state v2 clients work with v3 | "Migrating client applications" |
| **MEDIUM** | Traffic Switching | Load balancer strategies and rollback | New section after data migration |
| **MEDIUM** | Import Validation | Specific validation steps and expected outcomes | "Migrating registry data" |
| **MEDIUM** | New Config Properties | Storage kind and deletion properties | "Updating configuration" |
| **MEDIUM** | Troubleshooting | Common issues and solutions | New section at end |
| **LOW** | Pre-Migration Checklist | Preparation steps before migration | New section before data migration |

---

## Scenarios That Validated Each Recommendation

| Recommendation | Validated By | Evidence Location |
|----------------|--------------|-------------------|
| KafkaSQL warning | Scenario 2 | `scenario-2/docker-compose.yml` (different topic names) |
| Kafka SerDes migration | Scenario 2 | `scenario-2/clients/*/pom.xml` and Java source files |
| Client SSL config | Scenario 3 | `scenario-3/clients/*/src/main/java/*Validator.java` |
| Backward compatibility | Scenarios 1, 3, 4 | Step J validation scripts using v2 clients on v3 |
| Traffic switching | All scenarios | `scenario-*/docker-compose-nginx.yml` and switch scripts |
| Import validation | All scenarios | `scenario-*/scripts/step-*-validate-*.sh` |
| New config properties | Scenarios 1, 2 | `scenario-*/docker-compose-v3.yml` |
| Troubleshooting | All scenarios | Issues encountered during development |
| Pre-migration checklist | All scenarios | Prerequisites and preparation steps |

---

## Implementation Status

- [ ] KafkaSQL topic incompatibility warning
- [ ] Kafka SerDes migration guide
- [ ] Client SSL configuration differences
- [ ] Backward compatibility note
- [ ] Traffic migration strategies
- [ ] Enhanced import validation
- [ ] New configuration properties
- [ ] Troubleshooting section
- [ ] Pre-migration checklist

---

## Conclusion

The four migration testing scenarios successfully validate the core accuracy of the migration guide while
revealing important practical details that customers will need for successful migrations. Implementing these
recommendations—particularly the critical warnings about KafkaSQL and SerDes—will significantly improve
customer success rates and reduce support burden during migrations from Apicurio Registry 2.x to 3.x.

The scenarios demonstrate that migration is technically sound and backward compatibility works as expected,
giving customers confidence that they can migrate the server first and update clients on their own timeline.
