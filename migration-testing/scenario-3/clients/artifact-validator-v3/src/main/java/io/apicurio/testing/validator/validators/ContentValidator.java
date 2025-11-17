package io.apicurio.testing.validator.validators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.client.models.ArtifactSearchResults;
import io.apicurio.registry.rest.client.models.ArtifactSortBy;
import io.apicurio.registry.rest.client.models.SortOrder;
import io.apicurio.testing.validator.model.ValidationReport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Validates content retrieval by globalId and contentHash.
 */
public class ContentValidator {

    private static final Logger log = LoggerFactory.getLogger(ContentValidator.class);

    private final RegistryClient client;
    private final ValidationReport report;

    public ContentValidator(RegistryClient client, ValidationReport report) {
        this.client = client;
        this.report = report;
    }

    /**
     * Validates content retrieval.
     */
    public void validate() throws Exception {
        log.info("Validating content retrieval...");

        // Get all artifacts using v3 search API
        ArtifactSearchResults results = client.search().artifacts().get(config -> {
            config.queryParameters.groupId = "default";
            config.queryParameters.orderby = ArtifactSortBy.ArtifactId;
            config.queryParameters.order = SortOrder.Asc;
            config.queryParameters.offset = 0;
            config.queryParameters.limit = 1000;
        });

        // Collect version information
        List<VersionInfo> versions = new ArrayList<>();
        for (var artifact : results.getArtifacts()) {
            try {
                // List versions using v3 API
                var versionList = client.groups().byGroupId("default")
                    .artifacts().byArtifactId(artifact.getArtifactId())
                    .versions().get(config -> {
                        config.queryParameters.offset = 0;
                        config.queryParameters.limit = 100;
                    });
                for (var version : versionList.getVersions()) {
                    versions.add(new VersionInfo(
                        artifact.getArtifactId(),
                        version.getVersion(),
                        version.getGlobalId(),
                        version.getContentId()
                    ));
                }
            } catch (Exception e) {
                log.warn("  Failed to list versions for {}: {}", artifact.getArtifactId(), e.getMessage());
            }
        }

        log.info("  Found {} total versions to test", versions.size());

        // Shuffle and take random samples
        Collections.shuffle(versions);
        List<VersionInfo> sampleForGlobalId = versions.subList(0, Math.min(10, versions.size()));
        List<VersionInfo> sampleForContentId = versions.subList(0, Math.min(5, versions.size()));

        // Test retrieval by globalId
        validateGlobalIdRetrieval(sampleForGlobalId);

        // Test retrieval by contentId
        validateContentIdRetrieval(sampleForContentId);
    }

    /**
     * Validates content retrieval by globalId.
     *
     * @param versions list of versions to test
     */
    private void validateGlobalIdRetrieval(List<VersionInfo> versions) {
        log.info("  Testing content retrieval by globalId...");

        int successCount = 0;
        for (VersionInfo version : versions) {
            try {
                // Retrieve content using v3 API
                InputStream content = client.ids().globalIds().byGlobalId(version.globalId).get();
                if (content != null) {
                    // Read the content to verify it's not empty
                    byte[] bytes = content.readAllBytes();
                    if (bytes.length > 0) {
                        successCount++;
                        log.debug("    ✓ Retrieved content for globalId {} ({} bytes)",
                            version.globalId, bytes.length);
                    } else {
                        report.recordFailure(
                            "Content retrieval by globalId " + version.globalId,
                            "Content is empty (0 bytes)"
                        );
                    }
                } else {
                    report.recordFailure(
                        "Content retrieval by globalId " + version.globalId,
                        "Content stream is null"
                    );
                }
            } catch (Exception e) {
                report.recordFailure(
                    "Content retrieval by globalId " + version.globalId,
                    e.getMessage()
                );
                log.error("    ✗ Failed to retrieve content for globalId {}: {}",
                    version.globalId, e.getMessage());
            }
        }

        report.recordPass("Content retrieval by globalId (" + successCount + "/" + versions.size() + ")");
        log.info("    ✓ Successfully retrieved {}/{} by globalId", successCount, versions.size());
    }

    /**
     * Validates content retrieval by contentId.
     *
     * @param versions list of versions to test
     */
    private void validateContentIdRetrieval(List<VersionInfo> versions) {
        log.info("  Testing content retrieval by contentId...");

        int successCount = 0;
        for (VersionInfo version : versions) {
            try {
                // Retrieve content using v3 API
                InputStream content = client.ids().contentIds().byContentId(version.contentId).get();
                if (content != null) {
                    // Read the content to verify it's not empty
                    byte[] bytes = content.readAllBytes();
                    if (bytes.length > 0) {
                        successCount++;
                        log.debug("    ✓ Retrieved content for contentId {} ({} bytes)",
                            version.contentId, bytes.length);
                    } else {
                        report.recordFailure(
                            "Content retrieval by contentId " + version.contentId,
                            "Content is empty (0 bytes)"
                        );
                    }
                } else {
                    report.recordFailure(
                        "Content retrieval by contentId " + version.contentId,
                        "Content stream is null"
                    );
                }
            } catch (Exception e) {
                report.recordFailure(
                    "Content retrieval by contentId " + version.contentId,
                    e.getMessage()
                );
                log.error("    ✗ Failed to retrieve content for contentId {}: {}",
                    version.contentId, e.getMessage());
            }
        }

        report.recordPass("Content retrieval by contentId (" + successCount + "/" + versions.size() + ")");
        log.info("    ✓ Successfully retrieved {}/{} by contentId", successCount, versions.size());
    }

    /**
     * Simple holder for version information.
     */
    private static class VersionInfo {
        final String artifactId;
        final String version;
        final Long globalId;
        final Long contentId;

        VersionInfo(String artifactId, String version, Long globalId, Long contentId) {
            this.artifactId = artifactId;
            this.version = version;
            this.globalId = globalId;
            this.contentId = contentId;
        }
    }
}
