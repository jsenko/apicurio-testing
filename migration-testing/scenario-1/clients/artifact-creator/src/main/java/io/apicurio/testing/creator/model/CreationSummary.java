package io.apicurio.testing.creator.model;

import java.util.HashMap;
import java.util.Map;

/**
 * Summary of artifact creation results.
 * Tracks counts and details of all created artifacts.
 */
public class CreationSummary {

    private int totalArtifacts = 0;
    private int totalVersions = 0;
    private int totalReferences = 0;
    private int globalRules = 0;
    private int artifactRules = 0;

    private Map<String, Integer> artifactsByType = new HashMap<>();
    private Map<String, Integer> versionsByArtifact = new HashMap<>();

    /**
     * Records creation of a new artifact.
     *
     * @param artifactType the artifact type (AVRO, PROTOBUF, etc.)
     * @param artifactId the artifact identifier
     * @param versionCount number of versions created for this artifact
     */
    public void recordArtifact(String artifactType, String artifactId, int versionCount) {
        totalArtifacts++;
        totalVersions += versionCount;
        artifactsByType.merge(artifactType, 1, Integer::sum);
        versionsByArtifact.put(artifactId, versionCount);
    }

    /**
     * Records creation of an artifact reference.
     */
    public void recordReference() {
        totalReferences++;
    }

    /**
     * Records creation of a global rule.
     */
    public void recordGlobalRule() {
        globalRules++;
    }

    /**
     * Records creation of an artifact-specific rule.
     */
    public void recordArtifactRule() {
        artifactRules++;
    }

    public int getTotalArtifacts() {
        return totalArtifacts;
    }

    public int getTotalVersions() {
        return totalVersions;
    }

    public int getTotalReferences() {
        return totalReferences;
    }

    public int getGlobalRules() {
        return globalRules;
    }

    public int getArtifactRules() {
        return artifactRules;
    }

    public Map<String, Integer> getArtifactsByType() {
        return artifactsByType;
    }

    public Map<String, Integer> getVersionsByArtifact() {
        return versionsByArtifact;
    }

    /**
     * Prints a formatted summary to console.
     */
    public void printSummary() {
        System.out.println("\n" + "=".repeat(60));
        System.out.println("  Artifact Creation Summary");
        System.out.println("=".repeat(60));
        System.out.println();
        System.out.println("Total Artifacts:     " + totalArtifacts);
        System.out.println("Total Versions:      " + totalVersions);
        System.out.println("Total References:    " + totalReferences);
        System.out.println("Global Rules:        " + globalRules);
        System.out.println("Artifact Rules:      " + artifactRules);
        System.out.println();
        System.out.println("Artifacts by Type:");
        artifactsByType.forEach((type, count) ->
            System.out.println("  " + String.format("%-12s", type + ":") + count)
        );
        System.out.println();
        System.out.println("=".repeat(60));
    }
}
