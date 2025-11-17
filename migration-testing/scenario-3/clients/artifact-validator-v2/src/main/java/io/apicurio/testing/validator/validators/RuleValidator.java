package io.apicurio.testing.validator.validators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.v2.beans.Rule;
import io.apicurio.registry.types.RuleType;
import io.apicurio.testing.validator.model.ValidationReport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

/**
 * Validates global and artifact-specific rules.
 */
public class RuleValidator {

    private static final Logger log = LoggerFactory.getLogger(RuleValidator.class);

    private final RegistryClient client;
    private final ValidationReport report;

    public RuleValidator(RegistryClient client, ValidationReport report) {
        this.client = client;
        this.report = report;
    }

    /**
     * Validates all rules.
     */
    public void validate() throws Exception {
        log.info("Validating rules...");

        validateGlobalRules();
        validateArtifactRules();
    }

    /**
     * Validates global rules.
     */
    private void validateGlobalRules() throws Exception {
        log.info("  Checking global rules...");

        List<RuleType> globalRules = client.listGlobalRules();
        log.info("    Found {} global rules", globalRules.size());

        // Validate VALIDITY rule
        validateGlobalRule(RuleType.VALIDITY, "FULL");

        // Validate COMPATIBILITY rule
        validateGlobalRule(RuleType.COMPATIBILITY, "BACKWARD");
    }

    /**
     * Validates a specific global rule.
     *
     * @param ruleType the rule type to validate
     * @param expectedConfig the expected rule configuration
     */
    private void validateGlobalRule(RuleType ruleType, String expectedConfig) throws Exception {
        try {
            Rule rule = client.getGlobalRuleConfig(ruleType);
            String actualConfig = rule.getConfig();

            if (expectedConfig.equals(actualConfig)) {
                report.recordPass("Global rule " + ruleType + ": " + actualConfig);
                log.info("    ✓ Global rule {}: {}", ruleType, actualConfig);
            } else {
                report.recordFailure(
                    "Global rule " + ruleType,
                    "Expected config '" + expectedConfig + "' but found '" + actualConfig + "'"
                );
                log.error("    ✗ Global rule {}: expected '{}' but found '{}'",
                    ruleType, expectedConfig, actualConfig);
            }
        } catch (Exception e) {
            report.recordFailure(
                "Global rule " + ruleType,
                "Rule not found or error: " + e.getMessage()
            );
            log.error("    ✗ Global rule {} not found: {}", ruleType, e.getMessage());
        }
    }

    /**
     * Validates artifact-specific rules.
     */
    private void validateArtifactRules() throws Exception {
        log.info("  Checking artifact-specific rules...");

        // Check FORWARD compatibility rule on avro-schema-1
        validateArtifactRule("avro-schema-1", RuleType.COMPATIBILITY, "FORWARD");

        // Check NONE compatibility rule on json-schema-1
        validateArtifactRule("json-schema-1", RuleType.COMPATIBILITY, "NONE");
    }

    /**
     * Validates a specific artifact rule.
     *
     * @param artifactId the artifact to check
     * @param ruleType the rule type to validate
     * @param expectedConfig the expected rule configuration
     */
    private void validateArtifactRule(String artifactId, RuleType ruleType, String expectedConfig) throws Exception {
        try {
            Rule rule = client.getArtifactRuleConfig("default", artifactId, ruleType);
            String actualConfig = rule.getConfig();

            if (expectedConfig.equals(actualConfig)) {
                report.recordPass("Artifact rule " + artifactId + "/" + ruleType + ": " + actualConfig);
                log.info("    ✓ Artifact rule {}/{}: {}", artifactId, ruleType, actualConfig);
            } else {
                report.recordFailure(
                    "Artifact rule " + artifactId + "/" + ruleType,
                    "Expected config '" + expectedConfig + "' but found '" + actualConfig + "'"
                );
                log.error("    ✗ Artifact rule {}/{}: expected '{}' but found '{}'",
                    artifactId, ruleType, expectedConfig, actualConfig);
            }
        } catch (Exception e) {
            report.recordFailure(
                "Artifact rule " + artifactId + "/" + ruleType,
                "Rule not found or error: " + e.getMessage()
            );
            log.error("    ✗ Artifact rule {}/{} not found: {}", artifactId, ruleType, e.getMessage());
        }
    }
}
