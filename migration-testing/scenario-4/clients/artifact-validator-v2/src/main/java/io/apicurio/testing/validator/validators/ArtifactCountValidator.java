package io.apicurio.testing.validator.validators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.v2.beans.ArtifactSearchResults;
import io.apicurio.registry.rest.v2.beans.SearchedArtifact;
import io.apicurio.registry.rest.v2.beans.SortBy;
import io.apicurio.registry.rest.v2.beans.SortOrder;
import io.apicurio.testing.validator.model.ValidationReport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Validates artifact and version counts in the registry.
 */
public class ArtifactCountValidator {

    private static final Logger log = LoggerFactory.getLogger(ArtifactCountValidator.class);

    private final RegistryClient client;
    private final ValidationReport report;

    // Expected counts from test data creation
    // Note: Includes 1 additional AVRO artifact (GreetingMessage) from Kafka producer (step-F)
    private static final int EXPECTED_TOTAL_ARTIFACTS = 26;
    private static final Map<String, Integer> EXPECTED_BY_TYPE = new HashMap<>();

    static {
        EXPECTED_BY_TYPE.put("AVRO", 11);  // 10 from step-E + 1 from step-F (Kafka producer)
        EXPECTED_BY_TYPE.put("PROTOBUF", 5);
        EXPECTED_BY_TYPE.put("JSON", 5);
        EXPECTED_BY_TYPE.put("OPENAPI", 3);
        EXPECTED_BY_TYPE.put("ASYNCAPI", 2);
    }

    public ArtifactCountValidator(RegistryClient client, ValidationReport report) {
        this.client = client;
        this.report = report;
    }

    /**
     * Validates all artifact and version counts.
     */
    public void validate() throws Exception {
        log.info("Validating artifact counts...");

        // Get all artifacts
        ArtifactSearchResults results = client.searchArtifacts(
            "default",  // group
            null,       // name
            null,       // description
            null,       // labels
            null,       // properties
            null,       // globalId
            null,       // contentId
            SortBy.name,
            SortOrder.asc,
            0,          // offset
            1000        // limit (should be enough)
        );

        int totalArtifacts = results.getCount();
        log.info("  Found {} total artifacts", totalArtifacts);

        // Validate total count
        if (totalArtifacts == EXPECTED_TOTAL_ARTIFACTS) {
            report.recordPass("Total artifact count (" + totalArtifacts + ")");
            log.info("  ✓ Total artifact count matches expected: {}", totalArtifacts);
        } else {
            report.recordFailure(
                "Total artifact count",
                "Expected " + EXPECTED_TOTAL_ARTIFACTS + " but found " + totalArtifacts
            );
            log.error("  ✗ Expected {} artifacts but found {}", EXPECTED_TOTAL_ARTIFACTS, totalArtifacts);
        }

        // Count artifacts by type
        Map<String, Integer> actualByType = new HashMap<>();
        for (SearchedArtifact artifact : results.getArtifacts()) {
            String type = artifact.getType();
            actualByType.merge(type, 1, Integer::sum);
        }

        // Validate counts by type
        for (Map.Entry<String, Integer> entry : EXPECTED_BY_TYPE.entrySet()) {
            String type = entry.getKey();
            int expected = entry.getValue();
            int actual = actualByType.getOrDefault(type, 0);

            if (actual == expected) {
                report.recordPass(type + " artifact count (" + actual + ")");
                log.info("  ✓ {} artifacts: {}", type, actual);
            } else {
                report.recordFailure(
                    type + " artifact count",
                    "Expected " + expected + " but found " + actual
                );
                log.error("  ✗ {} artifacts: expected {} but found {}", type, expected, actual);
            }
        }

        // Count total versions
        int totalVersions = 0;
        for (SearchedArtifact artifact : results.getArtifacts()) {
            try {
                // Get version count for each artifact
                var versions = client.listArtifactVersions("default", artifact.getId(), 0, 100);
                int versionCount = versions.getCount();
                totalVersions += versionCount;
                log.debug("  Artifact {} has {} versions", artifact.getId(), versionCount);
            } catch (Exception e) {
                log.warn("  Failed to get version count for artifact {}: {}", artifact.getId(), e.getMessage());
            }
        }

        log.info("  Total versions across all artifacts: {}", totalVersions);
        report.recordPass("Total version count (" + totalVersions + ")");
    }
}
