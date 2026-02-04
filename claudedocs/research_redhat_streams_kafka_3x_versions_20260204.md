# Red Hat Streams for Apache Kafka 3.x Series: Latest Releases & Version Mapping

**Research Date:** February 4, 2026
**Research Focus:** Version 3.0+ releases (current as of February 2026)
**Research Depth:** Deep (Comprehensive, 3-4 hop multi-source investigation)
**Confidence Level:** High

## Executive Summary

Red Hat Streams for Apache Kafka version 3.0 was released in July 2025, marking a major version transition aligned
with Apache Kafka 4.0. Version 3.1.0 was released on December 12, 2025, representing the most recent release as of
February 2026.

**Key Findings:**
- **Latest Release:** Streams for Apache Kafka 3.1.0 (December 12, 2025)
- **Previous 3.x Release:** Streams for Apache Kafka 3.0.0 (July 8, 2025)
- **Current LTS (2.x series):** Streams for Apache Kafka 2.9.x
- **Major Architecture Change:** Version 3.0+ requires KRaft mode (ZooKeeper completely removed)

---

## Latest Version Matrix

| Red Hat Streams Version | Apache Kafka Version | Strimzi Version | Release Date | LTS Status | KRaft Required |
|------------------------|---------------------|-----------------|--------------|------------|----------------|
| **3.1.0** (Latest) | 4.1.x | 0.48.x - 0.49.x* | Dec 12, 2025 | TBD | **Yes** |
| **3.0.0** | 4.0 | 0.46.x | Jul 8, 2025 | No | **Yes** |
| 2.9.x (Current LTS) | 3.9.x | 0.45.x | Mar 5, 2025 | **Yes** | No |
| 2.8.x | 3.8.0 | 0.43.x | 2024 | No | No |

\* *Estimated based on Strimzi release timeline and Kafka 4.1 support. Red Hat has not publicly confirmed the exact
Strimzi version for 3.1.0 in readily accessible documentation.*

---

## Detailed Version Information

### Streams for Apache Kafka 3.1.0 (Current Latest Release)

**Release Date:** December 12, 2025

**Based on:**
- Apache Kafka 4.1.x (confirmed via Red Hat Ecosystem Catalog container "kafka-41-rhel9")
- Strimzi 0.48.x or 0.49.x (estimated based on Kafka 4.1 support timeline)

**Status:** Latest GA release, non-LTS

**Key Characteristics:**
- KRaft-only operation (no ZooKeeper support)
- Requires Java 17+
- MirrorMaker 2 only (MirrorMaker 1 removed)
- Built on RHEL 9.x base images

**Available Components:**
- Binary distribution (44.25 MB)
- Maven repository (159.5 MB)
- Cruise Control (56.15 MB)
- HTTP Bridge (127.84 MB)
- OpenShift Installation and Example Files (324.74 KB)
- OpenShift Diagnostic Tools (4.8 KB)
- Debezium 3.2.5 Connectors (Oracle, PostgreSQL, SQL Server, MongoDB, MariaDB, Db2, JDBC)
- Debezium Informix Connector (Developer Preview)

**Architecture Requirements:**
- **KRaft Mode Required:** All Kafka clusters must use KRaft (no ZooKeeper)
- **Migration Path:** Must upgrade to 2.9.x and complete ZooKeeper-to-KRaft migration before upgrading to 3.x
- **Java 17:** Required for all components (Java 11 no longer supported)

**Sources:**
- [Download Streams for Apache Kafka](https://developers.redhat.com/products/streams-for-apache-kafka/download)
- [Streams for Apache Kafka 3.1 Documentation](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.1)
- [Streams Kafka 4.1 Container - Red Hat Ecosystem Catalog](https://catalog.redhat.com/en/software/containers/amq-streams/kafka-41-rhel9/68a45890826db6453e13db61)

---

### Streams for Apache Kafka 3.0.0

**Release Date:** July 8, 2025

**Based on:**
- Apache Kafka 4.0
- Strimzi 0.46.x

**Status:** GA release, non-LTS

**Platform Support:**
- OpenShift Container Platform 4.14 to 4.19
- RHEL 9.2 base images with FIPS support

**Key Features and Breaking Changes:**

**1. KRaft Mode Mandatory**
- ZooKeeper support completely removed
- All clusters must operate in KRaft (Kafka Raft metadata) mode
- Metadata management and cluster coordination built directly into Kafka
- Migration from ZooKeeper must be completed on version 2.9 before upgrading to 3.0

**2. MirrorMaker 2 Only**
- Kafka MirrorMaker 1 removed in Kafka 4.0
- MirrorMaker 2 is the only available version for replication

**3. Tiered Storage (Production Ready)**
- Tiered storage moves from early access to production suitability
- Flexible approach to managing Kafka data by moving log segments to separate storage
- Requires implementation of Kafka's RemoteStorageManager interface
- Configured through Kafka resource

**4. Enhanced Security**
- Kafka node certificates stored in separate Secret resources (not in single shared Secret)
- FIPS-compliant container images based on RHEL 9.2

**5. Health Endpoints**
- Streams for Apache Kafka now supports /health endpoint for Kafka Connect REST API
- Used for health checks of Kafka Connect and MirrorMaker 2

**6. Configuration Changes**
- Multiple Kafka 4.0 configuration properties have updated constraints and default values (KIP-1030)
- Changes may impact performance or behavior even if properties not explicitly configured

**7. Logging Changes**
- Switch from Log4j 1.x to Log4j2 for logging

**Java Requirements:**
- **Brokers, Connect, Tools:** Java 17 required
- **Clients and Kafka Streams:** Java 11 minimum, Java 17 recommended
- Java 11 support completely removed from broker components

**Sources:**
- [Streams for Apache Kafka 3.0 Documentation](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.0)
- [Release Notes for Streams for Apache Kafka 3.0 on OpenShift](https://docs.redhat.com/es/documentation/red_hat_streams_for_apache_kafka/3.0/html-single/release_notes_for_streams_for_apache_kafka_3.0_on_openshift/index)
- [Release Notes for Streams for Apache Kafka 3.0 on RHEL](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.0/html-single/release_notes_for_streams_for_apache_kafka_3.0_on_rhel/index)
- [Streams for Apache Kafka 3.0: Kafka 4 impact and adoption](https://access.redhat.com/articles/7099120)

---

## Strimzi Version Reference (Upstream)

For context on the underlying Strimzi releases used in Red Hat Streams for Apache Kafka:

| Strimzi Version | Kafka Versions Supported | Kubernetes Support | Notable Changes |
|-----------------|-------------------------|-------------------|-----------------|
| **0.50.0** | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.27+ | Latest stable |
| **0.49.1** | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.27+ | Security fixes |
| **0.49.0** | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.27+ | API v1 for all CRDs, PEM certificates |
| **0.48.0** | 4.0.0, 4.1.0 | 1.27+ | Added Kafka 4.1 support, kube-state-metrics |
| **0.47.0** | 4.0.0 | 1.25-1.26 | Last version for K8s 1.25/1.26 |
| **0.46.1** | 3.9.0, 4.0.0 | 1.25+ | Kafka 4.0 support |
| **0.46.0** | 3.9.0, 4.0.0 | 1.25+ | **ZooKeeper removed**, KRaft required |

**Source:** [Strimzi Downloads](https://strimzi.io/downloads/)

---

## Apache Kafka 4.x Timeline

Understanding the upstream Apache Kafka release timeline provides context for Red Hat Streams releases:

**Apache Kafka 4.0.0**
- Released: March 18, 2025
- KRaft mandatory (ZooKeeper completely removed)
- Next Generation Consumer Rebalance Protocol (KIP-848) GA
- Queues for Kafka (Early Access)

**Apache Kafka 4.1.0**
- Released: Mid-2025
- Queues for Kafka moved to Preview state
- Enhanced rebalance performance
- Additional stability improvements

**Apache Kafka 4.2.0**
- Planned: January 2026 (in progress as of December 2025)
- Code freeze: December 10, 2025
- Queues for Kafka planned for production-ready status

**Sources:**
- [Apache Kafka 4.0 Release](https://www.confluent.io/blog/latest-apache-kafka-release/)
- [Apache Kafka 4.0: KRaft, New Features, and Migration](https://github.com/AutoMQ/automq/wiki/Apache-Kafka-4.0:-KRaft,-New-Features,-and-Migration)
- [Kafka Monthly Digest: December 2025](https://developers.redhat.com/blog/2026/01/08/kafka-monthly-digest-december-2025)
- [Apache Kafka Compatibility](https://kafka.apache.org/41/getting-started/compatibility/)

---

## Migration Paths

### From 2.x to 3.x (Critical Migration Requirements)

**Prerequisites:**
1. **Upgrade to 2.9.x first** - Must be on Streams for Apache Kafka 2.9.x before migrating to 3.0
2. **Complete ZooKeeper-to-KRaft migration** - All clusters must be fully migrated to KRaft mode on 2.9
3. **Upgrade to Java 17** - Java 11 not supported in 3.0+
4. **Migrate from MirrorMaker 1** - If using MirrorMaker 1, migrate to MirrorMaker 2 on 2.9

**Migration Steps:**

```
Current State → Step 1 → Step 2 → Step 3 → Target State
-------------   ------   ------   ------   ------------
ZooKeeper     → 2.9.x → KRaft  → Verify → 3.0+ KRaft
Cluster         (LTS)    Migration

Timeline:
- Step 1: Upgrade to 2.9.x (allows testing in ZooKeeper mode)
- Step 2: Migrate to KRaft while on 2.9.x (2.9 supports both ZooKeeper and KRaft)
- Step 3: Validate KRaft operation on 2.9.x
- Step 4: Upgrade to 3.0.0 or 3.1.0 (KRaft-only)
```

**Important Notes:**
- **No direct upgrade path** from ZooKeeper-based 2.x to 3.x
- Version 2.9.x is the **only** version that supports both ZooKeeper and KRaft, making it the migration bridge
- Cannot downgrade from 3.x to 2.x once upgraded
- Test migration thoroughly in non-production environments first

### From 3.0 to 3.1

Upgrading from 3.0 to 3.1 is straightforward as both are KRaft-only:
- Both versions require KRaft
- Both require Java 17
- Standard upgrade procedures apply
- Review release notes for any breaking changes or new features

---

## Support and Lifecycle Status

### Current Support Status (February 2026)

**Active Versions:**
- **3.1.0** - Latest release, full support (non-LTS)
- **3.0.0** - Supported (non-LTS)
- **2.9.x** - Current LTS (Long Term Support)
- **2.8.x** - Supported (non-LTS)
- **2.7.x** - Support status TBD
- **2.6.x** - Support status TBD
- **2.5.x** - Previous LTS (support status TBD)

**Note:** Specific lifecycle end dates require Red Hat Customer Portal access. See [Streams for Apache Kafka LTS
Support Policy](https://access.redhat.com/articles/6975608) and [Product Life Cycles](https://access.redhat.com/product-life-cycles?product=Streams%20for%20Apache%20Kafka).

### LTS vs Non-LTS

**Long Term Support (LTS) Releases:**
- Extended support lifecycle
- More conservative feature adoption
- Recommended for production deployments requiring stability
- Current LTS: 2.9.x

**Non-LTS Releases:**
- Shorter support lifecycle
- More rapid feature adoption
- Suitable for environments that can upgrade more frequently
- 3.0.0 and 3.1.0 are non-LTS

**Future LTS:** Red Hat has not yet announced which 3.x version will receive LTS designation.

---

## Recommendations

### For New Deployments (February 2026)

**Option 1: Use Latest (3.1.0)** ✅ Recommended for new KRaft deployments
- **Pros:** Latest features, modern architecture, long-term viability
- **Cons:** Non-LTS, shorter support lifecycle
- **Best for:** New projects, cloud-native deployments, teams comfortable with regular upgrades

**Option 2: Use Current LTS (2.9.x)** ✅ Recommended for conservative deployments
- **Pros:** Long-term support, stable, supports both ZooKeeper and KRaft
- **Cons:** Older Kafka version (3.9.x), will need to migrate to 3.x eventually
- **Best for:** Organizations requiring maximum stability, gradual migration strategies

**Not Recommended:**
- Starting new deployments on 3.0.0 (use 3.1.0 instead for latest fixes)
- Starting new ZooKeeper-based deployments (ZooKeeper removed in Kafka 4.x)

### For Existing Deployments

**If on 2.9.x (LTS):**
- ✅ Stay on 2.9.x if stability is paramount
- ✅ Begin planning KRaft migration to prepare for eventual 3.x upgrade
- ✅ Test KRaft mode on 2.9.x before committing to 3.x upgrade
- ✅ Upgrade to 3.1.0 if ready to adopt KRaft and Java 17

**If on 2.8.x or earlier non-LTS:**
- ✅ Upgrade to 2.9.x LTS for extended support
- ✅ Complete KRaft migration on 2.9.x
- ✅ Then upgrade to 3.1.0 when ready

**If on 2.5.x (Previous LTS):**
- ✅ Evaluate upgrade to 2.9.x (current LTS) or directly to 3.1.0
- ⚠️ Java 11 support: If must maintain Java 11, stay on 2.5.x or 2.9.x
- ⚠️ Direct upgrade to 3.x requires KRaft migration on interim version

**If on 3.0.0:**
- ✅ Upgrade to 3.1.0 for latest bug fixes and features
- ✅ Straightforward upgrade (both are KRaft-only)

### Technology Planning

**2026 and Beyond:**
- Apache Kafka 4.2.0 expected Q1 2026 (may lead to Red Hat Streams 3.2 later)
- Queues for Kafka feature approaching production-ready status
- Diskless topics proposals in Apache Kafka community (potential 2026-2027 feature)
- Expect Red Hat to designate a 3.x LTS version (possibly 3.2 or later)

**Key Trends:**
- KRaft is the future (ZooKeeper era ended with Kafka 3.9)
- Java 17+ required for modern Kafka
- Cloud-native optimizations ongoing (tiered storage, diskless topics)
- Multi-cluster operations improving (MirrorMaker 2 enhancements)

---

## Complete Version Comparison Table

| Version | Kafka | Strimzi | Release Date | ZooKeeper | KRaft | Java | MirrorMaker | LTS |
|---------|-------|---------|--------------|-----------|-------|------|-------------|-----|
| **3.1.0** | 4.1.x | ~0.48.x | Dec 12, 2025 | ❌ | ✅ | 17+ | MM2 only | ❓ |
| **3.0.0** | 4.0 | 0.46.x | Jul 8, 2025 | ❌ | ✅ | 17+ | MM2 only | ❌ |
| **2.9.x** | 3.9.x | 0.45.x | Mar 5, 2025 | ✅ | ✅ | 11/17 | MM1/MM2 | ✅ |
| 2.8.x | 3.8.0 | 0.43.x | 2024 | ✅ | TP→GA | 11/17 | MM1/MM2 | ❌ |
| 2.7.x | 3.7.0 | 0.40.x | 2024 | ✅ | TP | 11/17 | MM1/MM2 | ❌ |
| 2.6.x | 3.6.0 | 0.38.x | 2023 | ✅ | TP | 11/17 | MM1/MM2 | ❌ |
| 2.5.x | 3.5.0 | 0.36.x | 2023 | ✅ | TP | 11/17 | MM1/MM2 | ✅ |

**Legend:**
- ✅ = Supported/Available
- ❌ = Not Supported/Not Available
- TP = Technology Preview
- GA = General Availability
- MM1 = MirrorMaker 1
- MM2 = MirrorMaker 2
- ❓ = Unknown/Not yet announced

---

## Additional Resources

### Official Red Hat Documentation

**Version 3.1:**
- [Streams for Apache Kafka 3.1 Documentation Hub](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.1)
- [Download Streams for Apache Kafka 3.1.0](https://developers.redhat.com/products/streams-for-apache-kafka/download)
- [Kafka Configuration Tuning 3.1](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.1/html-single/kafka_configuration_tuning/kafka_configuration_tuning)
- [Developing Kafka Client Applications 3.1](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.1/pdf/developing_kafka_client_applications/Red_Hat_Streams_for_Apache_Kafka-3.1-Developing_Kafka_client_applications-en-US.pdf)

**Version 3.0:**
- [Streams for Apache Kafka 3.0 Documentation Hub](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.0)
- [Release Notes for Streams for Apache Kafka 3.0 on OpenShift](https://docs.redhat.com/es/documentation/red_hat_streams_for_apache_kafka/3.0/html-single/release_notes_for_streams_for_apache_kafka_3.0_on_openshift/index)
- [Release Notes for Streams for Apache Kafka 3.0 on RHEL](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/3.0/html-single/release_notes_for_streams_for_apache_kafka_3.0_on_rhel/index)
- [Streams for Apache Kafka 3.0: Kafka 4 impact and adoption](https://access.redhat.com/articles/7099120)

**General Resources:**
- [Streams for Apache Kafka Product Page](https://access.redhat.com/products/streams-apache-kafka/)
- [Red Hat Developer - Streams for Apache Kafka](https://developers.redhat.com/products/streams-for-apache-kafka)
- [Component Details (Requires Subscription)](https://access.redhat.com/articles/6649131)
- [Supported Configurations (Requires Subscription)](https://access.redhat.com/articles/6644711)
- [LTS Support Policy (Requires Subscription)](https://access.redhat.com/articles/6975608)

### Upstream/Community Resources

**Strimzi:**
- [Strimzi.io](https://strimzi.io/)
- [Strimzi Downloads](https://strimzi.io/downloads/)
- [Strimzi GitHub Repository](https://github.com/strimzi/strimzi-kafka-operator)
- [Strimzi GitHub Releases](https://github.com/strimzi/strimzi-kafka-operator/releases)
- [Strimzi Changelog](https://github.com/strimzi/strimzi-kafka-operator/blob/main/CHANGELOG.md)

**Apache Kafka:**
- [Apache Kafka Downloads](https://kafka.apache.org/community/downloads/)
- [Apache Kafka Compatibility Guide](https://kafka.apache.org/41/getting-started/compatibility/)
- [Apache Kafka Upgrade Guide](https://kafka.apache.org/40/getting-started/upgrade/)

**Community Blogs:**
- [Kafka Monthly Digest: December 2025](https://developers.redhat.com/blog/2026/01/08/kafka-monthly-digest-december-2025)
- [Kafka Monthly Digest: September 2025](https://developers.redhat.com/blog/2025/10/01/kafka-monthly-digest-september-2025)
- [Kafka Monthly Digest: March 2025](https://developers.redhat.com/blog/2025/04/01/kafka-monthly-digest-march-2025)
- [Using Queues for Apache Kafka with Strimzi](https://strimzi.io/blog/2025/08/20/queues-for-kafka/)

---

## Research Methodology

### Information Sources

This research utilized multiple authoritative sources:

1. **Red Hat Official Documentation**
   - Product documentation for versions 3.0 and 3.1
   - Release notes for OpenShift and RHEL deployments
   - Download portal information

2. **Red Hat Developer Portal**
   - Download pages with version and release date information
   - Kafka Monthly Digest articles (December 2025, September 2025, etc.)

3. **Red Hat Ecosystem Catalog**
   - Container image registry information
   - Component version verification

4. **Strimzi Project**
   - Official downloads page with version matrices
   - GitHub release notes and changelog
   - Upstream compatibility information

5. **Apache Kafka Project**
   - Release announcements and timelines
   - Compatibility and upgrade guides

6. **Community Sources**
   - Confluent and other vendor blogs about Kafka 4.0/4.1
   - Technical analysis and migration guides

### Confidence Assessment

**Overall Confidence: High**

**Confirmed Information (Very High Confidence):**
- Streams for Apache Kafka 3.1.0 released December 12, 2025 ✅
- Streams for Apache Kafka 3.0.0 released July 8, 2025 ✅
- Version 3.0 based on Strimzi 0.46.x and Kafka 4.0 ✅
- KRaft requirement for 3.x versions ✅
- Java 17 requirement for 3.x versions ✅
- ZooKeeper removal in 3.x ✅
- MirrorMaker 1 removal in 3.x ✅

**Estimated Information (High Confidence):**
- Streams 3.1.0 based on Kafka 4.1.x (very likely, inferred from container catalog) ✅
- Streams 3.1.0 based on Strimzi 0.48.x or 0.49.x (estimated from timeline) ⚠️

**Unknown/Requires Red Hat Subscription:**
- Exact Strimzi version for 3.1.0 (not confirmed in public docs) ❓
- Detailed support lifecycle end dates ❓
- Which 3.x version will be designated LTS ❓

### Limitations

1. **Strimzi Version for 3.1.0:** The exact Strimzi version for Streams 3.1.0 is estimated based on Kafka 4.1
support and release timeline, not confirmed in publicly accessible Red Hat documentation.

2. **Support Lifecycle Dates:** Specific GA, maintenance end, and extended support end dates require Red Hat
Customer Portal subscription access.

3. **Future Release Plans:** Red Hat has not publicly announced plans for versions beyond 3.1.0 or which 3.x version
will receive LTS designation.

4. **Red Hat Component Details Article:** The authoritative version mapping article (access.redhat.com/articles/6649131)
requires subscription access for complete information.

---

## Appendix: Key Differences Between 2.9.x (LTS) and 3.x

Understanding the differences helps inform upgrade decisions:

| Feature/Capability | 2.9.x (LTS) | 3.0+ |
|-------------------|-------------|------|
| **Architecture** |
| ZooKeeper Support | ✅ Yes | ❌ No (removed) |
| KRaft Support | ✅ Yes | ✅ Yes (required) |
| Hybrid Operation | ✅ Both modes | ❌ KRaft only |
| **Software Requirements** |
| Java 11 | ✅ Supported | ❌ Removed |
| Java 17 | ✅ Supported | ✅ Required |
| **Kafka Features** |
| Apache Kafka Version | 3.9.x | 4.0+ |
| MirrorMaker 1 | ✅ Supported | ❌ Removed |
| MirrorMaker 2 | ✅ Supported | ✅ Only option |
| Tiered Storage | TP | ✅ Production |
| Queues for Kafka | ❌ Not available | ✅ Available (EA/Preview) |
| **Strimzi** |
| Strimzi Version | 0.45.x | 0.46.x+ |
| ZooKeeper CRDs | ✅ Available | ❌ Removed |
| KafkaNodePools | GA | GA |
| **Migration** |
| ZK→KRaft Migration | ✅ Supported | ❌ N/A (must migrate first) |
| Upgrade from ZK-based | ✅ Direct | ❌ Must migrate to KRaft first |
| **Support** |
| LTS Status | ✅ Yes | ❓ TBD for future version |
| Support Timeline | Extended | Standard |

---

**Report Generated:** February 4, 2026
**Research Depth:** Deep (Comprehensive, multi-hop investigation)
**Last Updated:** 2026-02-04
**Supersedes:** Initial report `research_redhat_streams_kafka_versions_20260204.md`
