package io.apicurio.testing.creator.generators;

import com.fasterxml.jackson.databind.JsonNode;
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
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Generates Avro schema artifacts for testing.
 * Creates 10 artifacts with 3-5 versions each, including backward and forward compatible changes.
 */
public class AvroSchemaGenerator {

    private static final Logger log = LoggerFactory.getLogger(AvroSchemaGenerator.class);
    private static final ObjectMapper mapper = new ObjectMapper();

    private final RegistryClient client;
    private final CreationSummary summary;

    public AvroSchemaGenerator(RegistryClient client, CreationSummary summary) {
        this.client = client;
        this.summary = summary;
    }

    /**
     * Creates all Avro schema test artifacts.
     */
    public void createArtifacts() throws Exception {
        log.info("Creating Avro schema artifacts...");

        // Create 10 Avro schemas with different version counts
        for (int i = 1; i <= 10; i++) {
            String artifactId = "avro-schema-" + i;
            int versionCount = (i % 3) + 3; // 3-5 versions
            createAvroArtifact(artifactId, i, versionCount);
        }

        // Add COMPATIBILITY: FORWARD rule to one Avro artifact
        addForwardCompatibilityRule("avro-schema-1");
    }

    /**
     * Creates a single Avro artifact with multiple versions.
     *
     * @param artifactId artifact identifier
     * @param index artifact index for uniqueness
     * @param versionCount number of versions to create
     */
    private void createAvroArtifact(String artifactId, int index, int versionCount) throws Exception {
        log.info("  Creating artifact: {} ({} versions)", artifactId, versionCount);

        // Version 1: Base schema
        String schema1 = createBaseAvroSchema("Record" + index, Arrays.asList("id", "name"));
        ArtifactMetaData meta = client.createArtifact(
            "default",
            artifactId,
            ArtifactType.AVRO,
            new ByteArrayInputStream(schema1.getBytes(StandardCharsets.UTF_8))
        );

        // Add labels and properties
        EditableMetaData editMeta = new EditableMetaData();
        editMeta.setName(artifactId);
        editMeta.setDescription("Avro test schema #" + index);
        editMeta.setLabels(createLabels("avro"));
        editMeta.setProperties(createProperties());
        client.updateArtifactMetaData("default", artifactId, editMeta);

        // Create additional versions
        for (int v = 2; v <= versionCount; v++) {
            String schema = createVersionedAvroSchema("Record" + index, v);
            client.createArtifactVersion(
                "default",
                artifactId,
                null,
                new ByteArrayInputStream(schema.getBytes(StandardCharsets.UTF_8))
            );
        }

        summary.recordArtifact("AVRO", artifactId, versionCount);
        log.info("    ✓ Created {} with {} versions", artifactId, versionCount);
    }

    /**
     * Creates a base Avro schema with specified fields.
     *
     * @param recordName name of the Avro record
     * @param fieldNames list of field names to include
     * @return JSON string of the Avro schema
     */
    private String createBaseAvroSchema(String recordName, List<String> fieldNames) throws Exception {
        ObjectNode schema = mapper.createObjectNode();
        schema.put("type", "record");
        schema.put("name", recordName);
        schema.put("namespace", "io.apicurio.testing");

        ArrayNode fields = schema.putArray("fields");
        for (String fieldName : fieldNames) {
            ObjectNode field = fields.addObject();
            field.put("name", fieldName);
            field.put("type", "string");
        }

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(schema);
    }

    /**
     * Creates a versioned Avro schema with backward/forward compatible changes.
     *
     * @param recordName name of the Avro record
     * @param version version number
     * @return JSON string of the Avro schema
     */
    private String createVersionedAvroSchema(String recordName, int version) throws Exception {
        ObjectNode schema = mapper.createObjectNode();
        schema.put("type", "record");
        schema.put("name", recordName);
        schema.put("namespace", "io.apicurio.testing");

        ArrayNode fields = schema.putArray("fields");

        // Base fields (always present)
        ObjectNode idField = fields.addObject();
        idField.put("name", "id");
        idField.put("type", "string");

        ObjectNode nameField = fields.addObject();
        nameField.put("name", "name");
        nameField.put("type", "string");

        // Add new optional field for backward compatibility
        if (version >= 2) {
            ObjectNode emailField = fields.addObject();
            emailField.put("name", "email");
            ArrayNode emailType = emailField.putArray("type");
            emailType.add("null");
            emailType.add("string");
            emailField.put("default", mapper.nullNode());
        }

        // Add another optional field
        if (version >= 3) {
            ObjectNode phoneField = fields.addObject();
            phoneField.put("name", "phone");
            ArrayNode phoneType = phoneField.putArray("type");
            phoneType.add("null");
            phoneType.add("string");
            phoneField.put("default", mapper.nullNode());
        }

        // Add timestamp for versions 4+
        if (version >= 4) {
            ObjectNode timestampField = fields.addObject();
            timestampField.put("name", "timestamp");
            ArrayNode timestampType = timestampField.putArray("type");
            timestampType.add("null");
            timestampType.add("long");
            timestampField.put("default", mapper.nullNode());
        }

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(schema);
    }

    /**
     * Adds COMPATIBILITY: FORWARD rule to a specific artifact.
     *
     * @param artifactId the artifact to add the rule to
     */
    private void addForwardCompatibilityRule(String artifactId) throws Exception {
        log.info("  Adding FORWARD compatibility rule to {}", artifactId);
        Rule rule = new Rule();
        rule.setType(RuleType.COMPATIBILITY);
        rule.setConfig("FORWARD");
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
