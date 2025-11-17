package io.apicurio.testing.creator;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.client.RegistryClientFactory;
import io.apicurio.registry.rest.v2.beans.Rule;
import io.apicurio.registry.types.RuleType;
import io.apicurio.testing.creator.generators.AsyncApiGenerator;
import io.apicurio.testing.creator.generators.AvroSchemaGenerator;
import io.apicurio.testing.creator.generators.JsonSchemaGenerator;
import io.apicurio.testing.creator.generators.OpenApiGenerator;
import io.apicurio.testing.creator.generators.ProtobufSchemaGenerator;
import io.apicurio.testing.creator.model.CreationSummary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileWriter;
import java.io.PrintWriter;

/**
 * Main application for creating test artifacts in Apicurio Registry.
 *
 * This application creates a comprehensive set of test data including:
 * - 10 Avro schemas with 3-5 versions each
 * - 5 Protobuf schemas with 2-3 versions each
 * - 5 JSON schemas with 2-3 versions each
 * - 3 OpenAPI specifications with 2 versions each
 * - 2 AsyncAPI specifications with 2 versions each
 * - Global rules (VALIDITY, COMPATIBILITY)
 * - Artifact-specific rules
 *
 * Usage: java -jar artifact-creator.jar [registry-url] [output-file]
 *
 * Args:
 *   registry-url: URL of the Apicurio Registry (default: http://localhost:8080/apis/registry/v2)
 *   output-file:  Path to write the creation summary (default: data/creation-summary.txt)
 */
public class ArtifactCreatorApp {

    private static final Logger log = LoggerFactory.getLogger(ArtifactCreatorApp.class);

    private static final String DEFAULT_REGISTRY_URL = "http://localhost:8080/apis/registry/v2";
    private static final String DEFAULT_OUTPUT_FILE = "data/creation-summary.txt";

    public static void main(String[] args) {
        String registryUrl = args.length > 0 ? args[0] : DEFAULT_REGISTRY_URL;
        String outputFile = args.length > 1 ? args[1] : DEFAULT_OUTPUT_FILE;

        log.info("================================================================");
        log.info("  Apicurio Registry Artifact Creator");
        log.info("================================================================");
        log.info("Registry URL: {}", registryUrl);
        log.info("Output File:  {}", outputFile);
        log.info("");

        try {
            // Create registry client
            RegistryClient client = RegistryClientFactory.create(registryUrl);
            log.info("Connected to registry");

            // Create summary tracker
            CreationSummary summary = new CreationSummary();

            // Create global rules first
            createGlobalRules(client, summary);

            // Create artifacts by type
            new AvroSchemaGenerator(client, summary).createArtifacts();
            new ProtobufSchemaGenerator(client, summary).createArtifacts();
            new JsonSchemaGenerator(client, summary).createArtifacts();
            new OpenApiGenerator(client, summary).createArtifacts();
            new AsyncApiGenerator(client, summary).createArtifacts();

            // Print summary to console
            summary.printSummary();

            // Write summary to file
            writeSummaryToFile(summary, outputFile);

            log.info("");
            log.info("================================================================");
            log.info("  ✓ Artifact creation completed successfully");
            log.info("================================================================");
            log.info("Summary written to: {}", outputFile);

            System.exit(0);

        } catch (Exception e) {
            log.error("================================================================");
            log.error("  ✗ Artifact creation failed");
            log.error("================================================================");
            log.error("Error: {}", e.getMessage(), e);
            System.exit(1);
        }
    }

    /**
     * Creates global rules for the registry.
     *
     * @param client the registry client
     * @param summary the creation summary tracker
     */
    private static void createGlobalRules(RegistryClient client, CreationSummary summary) throws Exception {
        log.info("Creating global rules...");

        // VALIDITY: FULL
        Rule validityRule = new Rule();
        validityRule.setType(RuleType.VALIDITY);
        validityRule.setConfig("FULL");
        client.createGlobalRule(validityRule);
        summary.recordGlobalRule();
        log.info("  ✓ Created VALIDITY: FULL rule");

        // COMPATIBILITY: BACKWARD
        Rule compatibilityRule = new Rule();
        compatibilityRule.setType(RuleType.COMPATIBILITY);
        compatibilityRule.setConfig("BACKWARD");
        client.createGlobalRule(compatibilityRule);
        summary.recordGlobalRule();
        log.info("  ✓ Created COMPATIBILITY: BACKWARD rule");

        log.info("");
    }

    /**
     * Writes the creation summary to a file.
     *
     * @param summary the creation summary
     * @param outputFile path to the output file
     */
    private static void writeSummaryToFile(CreationSummary summary, String outputFile) throws Exception {
        try (PrintWriter writer = new PrintWriter(new FileWriter(outputFile))) {
            writer.println("Artifact Creation Summary");
            writer.println("=".repeat(60));
            writer.println();
            writer.println("Total Artifacts:     " + summary.getTotalArtifacts());
            writer.println("Total Versions:      " + summary.getTotalVersions());
            writer.println("Total References:    " + summary.getTotalReferences());
            writer.println("Global Rules:        " + summary.getGlobalRules());
            writer.println("Artifact Rules:      " + summary.getArtifactRules());
            writer.println();
            writer.println("Artifacts by Type:");
            summary.getArtifactsByType().forEach((type, count) ->
                writer.println("  " + String.format("%-12s", type + ":") + count)
            );
            writer.println();
            writer.println("Versions by Artifact:");
            summary.getVersionsByArtifact().forEach((artifactId, count) ->
                writer.println("  " + String.format("%-30s", artifactId + ":") + count)
            );
            writer.println();
            writer.println("=".repeat(60));
        }
        log.info("Summary written to: {}", outputFile);
    }
}
