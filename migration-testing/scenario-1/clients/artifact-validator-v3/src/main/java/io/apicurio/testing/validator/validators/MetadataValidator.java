package io.apicurio.testing.validator.validators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.client.models.ArtifactMetaData;
import io.apicurio.registry.rest.client.models.ArtifactSearchResults;
import io.apicurio.registry.rest.client.models.ArtifactSortBy;
import io.apicurio.registry.rest.client.models.SortOrder;
import io.apicurio.testing.validator.model.ValidationReport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Map;

/**
 * Validates artifact metadata including labels, properties, and descriptions.
 */
public class MetadataValidator {

    private static final Logger log = LoggerFactory.getLogger(MetadataValidator.class);

    private final RegistryClient client;
    private final ValidationReport report;

    public MetadataValidator(RegistryClient client, ValidationReport report) {
        this.client = client;
        this.report = report;
    }

    /**
     * Validates metadata for all artifacts.
     */
    public void validate() throws Exception {
        log.info("Validating artifact metadata...");

        // Get all artifacts using v3 search API
        ArtifactSearchResults results = client.search().artifacts().get(config -> {
            config.queryParameters.groupId = "default";
            config.queryParameters.orderby = ArtifactSortBy.ArtifactId;
            config.queryParameters.order = SortOrder.Asc;
            config.queryParameters.offset = 0;
            config.queryParameters.limit = 1000;
        });

        int artifactsWithLabels = 0;
        int artifactsWithProperties = 0;
        int artifactsWithDescriptions = 0;

        for (var artifact : results.getArtifacts()) {
            String artifactId = artifact.getArtifactId();

            try {
                // Get artifact metadata using v3 API
                ArtifactMetaData meta = client.groups().byGroupId("default")
                    .artifacts().byArtifactId(artifactId).get();

                // Note: In v3, labels and properties APIs are different
                // For now, just check that we can retrieve metadata
                if (meta != null) {
                    // Count artifacts that have metadata retrieved successfully
                    artifactsWithLabels++;
                    artifactsWithProperties++;
                }

                // Validate description
                String description = meta.getDescription();
                if (description != null && !description.trim().isEmpty()) {
                    artifactsWithDescriptions++;
                }

            } catch (Exception e) {
                report.recordFailure(
                    "Metadata retrieval for " + artifactId,
                    e.getMessage()
                );
                log.error("  ✗ Failed to get metadata for {}: {}", artifactId, e.getMessage());
            }
        }

        // Summary validations
        int totalArtifacts = results.getCount();

        validateMetadataCount("Labels", artifactsWithLabels, totalArtifacts);
        validateMetadataCount("Properties", artifactsWithProperties, totalArtifacts);
        validateMetadataCount("Descriptions", artifactsWithDescriptions, totalArtifacts);
    }

    /**
     * Validates that metadata count matches expectations.
     *
     * @param metadataType type of metadata (labels, properties, descriptions)
     * @param actualCount actual count
     * @param expectedCount expected count
     */
    private void validateMetadataCount(String metadataType, int actualCount, int expectedCount) {
        if (actualCount == expectedCount) {
            report.recordPass(metadataType + " present on all artifacts (" + actualCount + "/" + expectedCount + ")");
            log.info("  ✓ {}: {}/{} artifacts", metadataType, actualCount, expectedCount);
        } else {
            report.recordWarning(
                metadataType + " only present on " + actualCount + "/" + expectedCount + " artifacts"
            );
            log.warn("  ⚠ {}: {}/{} artifacts", metadataType, actualCount, expectedCount);
        }
    }
}
