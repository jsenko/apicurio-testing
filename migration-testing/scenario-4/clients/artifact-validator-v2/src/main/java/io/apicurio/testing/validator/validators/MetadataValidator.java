package io.apicurio.testing.validator.validators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.v2.beans.ArtifactMetaData;
import io.apicurio.registry.rest.v2.beans.ArtifactSearchResults;
import io.apicurio.registry.rest.v2.beans.SearchedArtifact;
import io.apicurio.registry.rest.v2.beans.SortBy;
import io.apicurio.registry.rest.v2.beans.SortOrder;
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
            1000        // limit
        );

        int artifactsWithLabels = 0;
        int artifactsWithProperties = 0;
        int artifactsWithDescriptions = 0;

        for (SearchedArtifact artifact : results.getArtifacts()) {
            String artifactId = artifact.getId();

            try {
                // Get artifact metadata
                ArtifactMetaData meta = client.getArtifactMetaData("default", artifactId);

                // Validate labels (labels are List<String> in format "key:value")
                List<String> labels = meta.getLabels();
                if (labels != null && !labels.isEmpty()) {
                    artifactsWithLabels++;

                    // Check for expected labels
                    boolean hasTypeLabel = labels.stream().anyMatch(l -> l.startsWith("type:"));
                    boolean hasEnvLabel = labels.stream().anyMatch(l -> l.equals("env:test"));

                    if (!hasTypeLabel) {
                        report.recordWarning("Artifact " + artifactId + " missing 'type' label");
                    }
                    if (!hasEnvLabel) {
                        report.recordWarning("Artifact " + artifactId + " missing 'env:test' label");
                    }
                }

                // Validate properties
                Map<String, String> properties = meta.getProperties();
                if (properties != null && !properties.isEmpty()) {
                    artifactsWithProperties++;

                    // Check for expected properties
                    if (!properties.containsKey("owner")) {
                        report.recordWarning("Artifact " + artifactId + " missing 'owner' property");
                    }
                    if (!properties.containsKey("version")) {
                        report.recordWarning("Artifact " + artifactId + " missing 'version' property");
                    }
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
