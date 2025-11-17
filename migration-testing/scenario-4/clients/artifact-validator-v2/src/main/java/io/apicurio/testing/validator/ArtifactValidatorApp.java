package io.apicurio.testing.validator;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.client.RegistryClientFactory;
import io.apicurio.rest.client.auth.Auth;
import io.apicurio.rest.client.auth.OidcAuth;
import io.apicurio.rest.client.auth.exception.AuthErrorHandler;
import io.apicurio.rest.client.spi.ApicurioHttpClient;
import io.apicurio.rest.client.spi.ApicurioHttpClientFactory;
import io.apicurio.testing.validator.model.ValidationReport;
import io.apicurio.testing.validator.validators.ArtifactCountValidator;
import io.apicurio.testing.validator.validators.ContentValidator;
import io.apicurio.testing.validator.validators.MetadataValidator;
import io.apicurio.testing.validator.validators.RuleValidator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.Collections;

/**
 * Main application for validating artifacts in Apicurio Registry using v2 API.
 *
 * This application performs comprehensive validation including:
 * - Artifact and version count validation
 * - Metadata validation (labels, properties, descriptions)
 * - Global and artifact-specific rule validation
 * - Content retrieval validation (by globalId and contentId)
 *
 * Usage: java -jar artifact-validator-v2.jar [registry-url] [output-file]
 *
 * Args:
 *   registry-url: URL of the Apicurio Registry (default: http://localhost:8080/apis/registry/v2)
 *   output-file:  Path to write the validation report (default: data/validation-report-v2.txt)
 */
public class ArtifactValidatorApp {

    private static final Logger log = LoggerFactory.getLogger(ArtifactValidatorApp.class);

    private static final String DEFAULT_REGISTRY_URL = "http://localhost:8080/apis/registry/v2";
    private static final String DEFAULT_OUTPUT_FILE = "data/validation-report-v2.txt";

    public static void main(String[] args) {
        String registryUrl = args.length > 0 ? args[0] : DEFAULT_REGISTRY_URL;
        String outputFile = args.length > 1 ? args[1] : DEFAULT_OUTPUT_FILE;

        log.info("================================================================");
        log.info("  Apicurio Registry Artifact Validator (v2 API)");
        log.info("================================================================");
        log.info("Registry URL: {}", registryUrl);
        log.info("Output File:  {}", outputFile);
        log.info("");

        try {
            // Create registry client with OIDC authentication for v2 client
            RegistryClient client = createAuthenticatedClient(registryUrl);
            log.info("Connected to registry");
            log.info("");

            // Create validation report
            ValidationReport report = new ValidationReport();

            // Run all validations
            new ArtifactCountValidator(client, report).validate();
            log.info("");

            new MetadataValidator(client, report).validate();
            log.info("");

            new RuleValidator(client, report).validate();
            log.info("");

            new ContentValidator(client, report).validate();
            log.info("");

            // Print report to console
            report.printReport();

            // Write report to file
            writeReportToFile(report, outputFile);

            log.info("");
            log.info("================================================================");
            if (report.allPassed()) {
                log.info("  ✓ Validation completed successfully - ALL CHECKS PASSED");
                log.info("================================================================");
                log.info("Report written to: {}", outputFile);
                System.exit(0);
            } else {
                log.info("  ✗ Validation completed with FAILURES");
                log.info("================================================================");
                log.info("Report written to: {}", outputFile);
                System.exit(1);
            }

        } catch (Exception e) {
            log.error("================================================================");
            log.error("  ✗ Validation failed with error");
            log.error("================================================================");
            log.error("Error: {}", e.getMessage(), e);
            System.exit(2);
        }
    }

    /**
     * Creates an authenticated registry client for the v2 API.
     * Uses OIDC client credentials flow with the developer-client from Keycloak.
     *
     * Configuration can be overridden via system properties:
     * - apicurio.auth.server.url
     * - apicurio.auth.client.id
     * - apicurio.auth.client.secret
     * - apicurio.auth.client.scope
     *
     * @param registryUrl the URL of the registry
     * @return authenticated RegistryClient
     */
    private static RegistryClient createAuthenticatedClient(String registryUrl) {
        String authServerUrl = System.getProperty("apicurio.auth.server.url",
                "https://localhost:9443/realms/registry");
        String clientId = System.getProperty("apicurio.auth.client.id", "developer-client");
        String clientSecret = System.getProperty("apicurio.auth.client.secret", "test1");
        String clientScope = System.getProperty("apicurio.auth.client.scope", null);

        log.info("OIDC Authentication configured:");
        log.info("  Auth Server URL: {}", authServerUrl);
        log.info("  Client ID: {}", clientId);
        if (clientScope != null) {
            log.info("  Client Scope: {}", clientScope);
        }
        log.info("");

        // Create HTTP client for OIDC authentication
        ApicurioHttpClient httpClient = ApicurioHttpClientFactory.create(authServerUrl, new AuthErrorHandler());

        // Create OIDC auth with client credentials (username is null for client credentials flow)
        Auth auth = new OidcAuth(httpClient, clientId, clientSecret, null, clientScope);

        // Create registry client with auth
        return RegistryClientFactory.create(registryUrl, Collections.emptyMap(), auth);
    }

    /**
     * Writes the validation report to a file.
     *
     * @param report the validation report
     * @param outputFile path to the output file
     */
    private static void writeReportToFile(ValidationReport report, String outputFile) throws Exception {
        try (PrintWriter writer = new PrintWriter(new FileWriter(outputFile))) {
            writer.println("Validation Report");
            writer.println("=".repeat(60));
            writer.println();
            writer.println("Total Checks:    " + report.getTotalChecks());
            writer.println("Passed:          " + report.getPassedChecks() + " ✓");
            writer.println("Failed:          " + report.getFailedChecks() + (report.getFailedChecks() > 0 ? " ✗" : ""));
            writer.println();

            if (!report.getFailures().isEmpty()) {
                writer.println("Failures:");
                for (String failure : report.getFailures()) {
                    writer.println("  ✗ " + failure);
                }
                writer.println();
            }

            if (!report.getWarnings().isEmpty()) {
                writer.println("Warnings:");
                for (String warning : report.getWarnings()) {
                    writer.println("  ⚠ " + warning);
                }
                writer.println();
            }

            if (report.allPassed()) {
                writer.println("✓ All validations passed!");
            } else {
                writer.println("✗ Some validations failed");
            }

            writer.println("=".repeat(60));
        }
        log.info("Report written to: {}", outputFile);
    }
}
