package io.apicurio.testing.validator.model;

import java.util.ArrayList;
import java.util.List;

/**
 * Report of validation results.
 * Tracks all validation checks and their outcomes.
 */
public class ValidationReport {

    private int totalChecks = 0;
    private int passedChecks = 0;
    private int failedChecks = 0;

    private List<String> failures = new ArrayList<>();
    private List<String> warnings = new ArrayList<>();

    /**
     * Records a successful validation check.
     *
     * @param checkName name of the validation check
     */
    public void recordPass(String checkName) {
        totalChecks++;
        passedChecks++;
    }

    /**
     * Records a failed validation check.
     *
     * @param checkName name of the validation check
     * @param reason reason for failure
     */
    public void recordFailure(String checkName, String reason) {
        totalChecks++;
        failedChecks++;
        failures.add(checkName + ": " + reason);
    }

    /**
     * Records a warning (not a failure, but noteworthy).
     *
     * @param message warning message
     */
    public void recordWarning(String message) {
        warnings.add(message);
    }

    /**
     * Checks if all validations passed.
     *
     * @return true if all checks passed, false otherwise
     */
    public boolean allPassed() {
        return failedChecks == 0;
    }

    public int getTotalChecks() {
        return totalChecks;
    }

    public int getPassedChecks() {
        return passedChecks;
    }

    public int getFailedChecks() {
        return failedChecks;
    }

    public List<String> getFailures() {
        return failures;
    }

    public List<String> getWarnings() {
        return warnings;
    }

    /**
     * Prints a formatted report to console.
     */
    public void printReport() {
        System.out.println("\n" + "=".repeat(60));
        System.out.println("  Validation Report");
        System.out.println("=".repeat(60));
        System.out.println();
        System.out.println("Total Checks:    " + totalChecks);
        System.out.println("Passed:          " + passedChecks + " ✓");
        System.out.println("Failed:          " + failedChecks + (failedChecks > 0 ? " ✗" : ""));
        System.out.println();

        if (!failures.isEmpty()) {
            System.out.println("Failures:");
            for (String failure : failures) {
                System.out.println("  ✗ " + failure);
            }
            System.out.println();
        }

        if (!warnings.isEmpty()) {
            System.out.println("Warnings:");
            for (String warning : warnings) {
                System.out.println("  ⚠ " + warning);
            }
            System.out.println();
        }

        if (allPassed()) {
            System.out.println("✓ All validations passed!");
        } else {
            System.out.println("✗ Some validations failed");
        }

        System.out.println("=".repeat(60));
    }
}
