package io.apicurio.testing.creator.generators;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.v2.beans.ArtifactMetaData;
import io.apicurio.registry.rest.v2.beans.EditableMetaData;
import io.apicurio.registry.rest.v2.beans.Rule;
import io.apicurio.registry.types.ArtifactType;
import io.apicurio.registry.types.RuleType;
import io.apicurio.testing.creator.model.CreationSummary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Generates JSON Schema artifacts for testing.
 * Creates 5 artifacts with 2-3 versions each.
 */
public class JsonSchemaGenerator {

    private static final Logger log = LoggerFactory.getLogger(JsonSchemaGenerator.class);
    private static final ObjectMapper mapper = new ObjectMapper();

    private final RegistryClient client;
    private final CreationSummary summary;

    public JsonSchemaGenerator(RegistryClient client, CreationSummary summary) {
        this.client = client;
        this.summary = summary;
    }

    /**
     * Creates all JSON Schema test artifacts.
     */
    public void createArtifacts() throws Exception {
        log.info("Creating JSON Schema artifacts...");

        // Create 5 JSON schemas with different version counts
        for (int i = 1; i <= 5; i++) {
            String artifactId = "json-schema-" + i;
            int versionCount = (i % 2) + 2; // 2-3 versions
            boolean addNoneRule = (i == 1); // Add NONE rule to first artifact
            createJsonSchemaArtifact(artifactId, i, versionCount, addNoneRule);
        }
    }

    /**
     * Creates a single JSON Schema artifact with multiple versions.
     *
     * @param artifactId artifact identifier
     * @param index artifact index for uniqueness
     * @param versionCount number of versions to create
     * @param addNoneRule whether to add COMPATIBILITY: NONE rule before creating additional versions
     */
    private void createJsonSchemaArtifact(String artifactId, int index, int versionCount, boolean addNoneRule) throws Exception {
        log.info("  Creating artifact: {} ({} versions)", artifactId, versionCount);

        // Version 1: Base schema
        String schema1 = createBaseJsonSchema("Entity" + index);
        ArtifactMetaData meta = client.createArtifact(
            "default",
            artifactId,
            ArtifactType.JSON,
            new ByteArrayInputStream(schema1.getBytes(StandardCharsets.UTF_8))
        );

        // Add labels and properties
        EditableMetaData editMeta = new EditableMetaData();
        editMeta.setName(artifactId);
        editMeta.setDescription("JSON Schema test #" + index);
        editMeta.setLabels(createLabels("json"));
        editMeta.setProperties(createProperties());
        client.updateArtifactMetaData("default", artifactId, editMeta);

        // Add COMPATIBILITY: NONE rule if requested (must be done before creating version 2)
        if (addNoneRule) {
            addNoneCompatibilityRule(artifactId);
        }

        // Create additional versions
        for (int v = 2; v <= versionCount; v++) {
            String schema = createVersionedJsonSchema("Entity" + index, v);
            client.createArtifactVersion(
                "default",
                artifactId,
                null,
                new ByteArrayInputStream(schema.getBytes(StandardCharsets.UTF_8))
            );
        }

        summary.recordArtifact("JSON", artifactId, versionCount);
        log.info("    ✓ Created {} with {} versions", artifactId, versionCount);
    }

    /**
     * Creates a base JSON Schema with all fields required.
     * Later versions will relax these requirements (backward compatible).
     *
     * @param title schema title
     * @return JSON Schema string
     */
    private String createBaseJsonSchema(String title) throws Exception {
        ObjectNode schema = mapper.createObjectNode();
        schema.put("$schema", "http://json-schema.org/draft-07/schema#");
        schema.put("title", title);
        schema.put("type", "object");

        ObjectNode properties = schema.putObject("properties");

        ObjectNode idProp = properties.putObject("id");
        idProp.put("type", "string");
        idProp.put("description", "Unique identifier");

        ObjectNode nameProp = properties.putObject("name");
        nameProp.put("type", "string");
        nameProp.put("description", "Name of the entity");

        ObjectNode emailProp = properties.putObject("email");
        emailProp.put("type", "string");
        emailProp.put("format", "email");
        emailProp.put("description", "Email address");

        ObjectNode statusProp = properties.putObject("status");
        statusProp.put("type", "string");
        statusProp.put("description", "Status of the entity");

        ArrayNode required = schema.putArray("required");
        required.add("id");
        required.add("name");
        required.add("email");
        required.add("status");

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(schema);
    }

    /**
     * Creates a versioned JSON Schema with backward-compatible changes.
     * Instead of adding new properties (which the registry considers narrowing),
     * we make backward-compatible changes by relaxing constraints.
     *
     * @param title schema title
     * @param version version number
     * @return JSON Schema string
     */
    private String createVersionedJsonSchema(String title, int version) throws Exception {
        ObjectNode schema = mapper.createObjectNode();
        schema.put("$schema", "http://json-schema.org/draft-07/schema#");
        schema.put("title", title);
        schema.put("type", "object");

        ObjectNode properties = schema.putObject("properties");

        ObjectNode idProp = properties.putObject("id");
        idProp.put("type", "string");
        idProp.put("description", "Unique identifier");

        ObjectNode nameProp = properties.putObject("name");
        nameProp.put("type", "string");
        nameProp.put("description", "Name of the entity");

        ObjectNode emailProp = properties.putObject("email");
        emailProp.put("type", "string");
        emailProp.put("format", "email");
        emailProp.put("description", "Email address");

        ObjectNode statusProp = properties.putObject("status");
        statusProp.put("type", "string");
        statusProp.put("description", "Status of the entity");

        // Version 1: All fields required
        // Version 2+: Make some fields optional (backward compatible)
        ArrayNode required = schema.putArray("required");
        required.add("id");
        if (version < 2) {
            required.add("name");
            required.add("email");
            required.add("status");
        } else if (version < 3) {
            required.add("name");
            // email and status become optional in v2 (backward compatible)
        } else {
            // only id required in v3+ (backward compatible)
        }

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(schema);
    }

    /**
     * Adds COMPATIBILITY: NONE rule to a specific artifact.
     *
     * @param artifactId the artifact to add the rule to
     */
    private void addNoneCompatibilityRule(String artifactId) throws Exception {
        log.info("  Adding NONE compatibility rule to {}", artifactId);
        Rule rule = new Rule();
        rule.setType(RuleType.COMPATIBILITY);
        rule.setConfig("NONE");
        client.createArtifactRule("default", artifactId, rule);
        summary.recordArtifactRule();
    }

    /**
     * Creates standard labels for artifacts.
     * Labels in v2 API are a list of strings in "key:value" format.
     *
     * @param type artifact type
     * @return list of labels
     */
    private List<String> createLabels(String type) {
        List<String> labels = new ArrayList<>();
        labels.add("type:" + type);
        labels.add("env:test");
        return labels;
    }

    /**
     * Creates standard properties for artifacts.
     *
     * @return map of properties
     */
    private Map<String, String> createProperties() {
        Map<String, String> properties = new HashMap<>();
        properties.put("owner", "test-suite");
        properties.put("version", "1.0");
        return properties;
    }
}
