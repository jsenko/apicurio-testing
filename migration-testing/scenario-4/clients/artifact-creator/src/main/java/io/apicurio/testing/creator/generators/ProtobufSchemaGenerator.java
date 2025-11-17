package io.apicurio.testing.creator.generators;

import io.apicurio.registry.rest.client.RegistryClient;
import io.apicurio.registry.rest.v2.beans.ArtifactMetaData;
import io.apicurio.registry.rest.v2.beans.EditableMetaData;
import io.apicurio.registry.types.ArtifactType;
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
 * Generates Protobuf schema artifacts for testing.
 * Creates 5 artifacts with 2-3 versions each.
 */
public class ProtobufSchemaGenerator {

    private static final Logger log = LoggerFactory.getLogger(ProtobufSchemaGenerator.class);

    private final RegistryClient client;
    private final CreationSummary summary;

    public ProtobufSchemaGenerator(RegistryClient client, CreationSummary summary) {
        this.client = client;
        this.summary = summary;
    }

    /**
     * Creates all Protobuf schema test artifacts.
     */
    public void createArtifacts() throws Exception {
        log.info("Creating Protobuf schema artifacts...");

        // Create 5 Protobuf schemas with different version counts
        for (int i = 1; i <= 5; i++) {
            String artifactId = "protobuf-schema-" + i;
            int versionCount = (i % 2) + 2; // 2-3 versions
            createProtobufArtifact(artifactId, i, versionCount);
        }
    }

    /**
     * Creates a single Protobuf artifact with multiple versions.
     *
     * @param artifactId artifact identifier
     * @param index artifact index for uniqueness
     * @param versionCount number of versions to create
     */
    private void createProtobufArtifact(String artifactId, int index, int versionCount) throws Exception {
        log.info("  Creating artifact: {} ({} versions)", artifactId, versionCount);

        // Version 1: Base schema
        String schema1 = createBaseProtobufSchema("Message" + index);
        ArtifactMetaData meta = client.createArtifact(
            "default",
            artifactId,
            ArtifactType.PROTOBUF,
            new ByteArrayInputStream(schema1.getBytes(StandardCharsets.UTF_8))
        );

        // Add labels and properties
        EditableMetaData editMeta = new EditableMetaData();
        editMeta.setName(artifactId);
        editMeta.setDescription("Protobuf test schema #" + index);
        editMeta.setLabels(createLabels("protobuf"));
        editMeta.setProperties(createProperties());
        client.updateArtifactMetaData("default", artifactId, editMeta);

        // Create additional versions
        for (int v = 2; v <= versionCount; v++) {
            String schema = createVersionedProtobufSchema("Message" + index, v);
            client.createArtifactVersion(
                "default",
                artifactId,
                null,
                new ByteArrayInputStream(schema.getBytes(StandardCharsets.UTF_8))
            );
        }

        summary.recordArtifact("PROTOBUF", artifactId, versionCount);
        log.info("    ✓ Created {} with {} versions", artifactId, versionCount);
    }

    /**
     * Creates a base Protobuf schema.
     *
     * @param messageName name of the Protobuf message
     * @return Protobuf schema string
     */
    private String createBaseProtobufSchema(String messageName) {
        return String.format(
            "syntax = \"proto3\";\n" +
            "\n" +
            "package io.apicurio.testing;\n" +
            "\n" +
            "message %s {\n" +
            "  string id = 1;\n" +
            "  string name = 2;\n" +
            "}\n",
            messageName
        );
    }

    /**
     * Creates a versioned Protobuf schema with additional fields.
     *
     * @param messageName name of the Protobuf message
     * @param version version number
     * @return Protobuf schema string
     */
    private String createVersionedProtobufSchema(String messageName, int version) {
        StringBuilder schema = new StringBuilder();
        schema.append("syntax = \"proto3\";\n\n");
        schema.append("package io.apicurio.testing;\n\n");
        schema.append("message ").append(messageName).append(" {\n");
        schema.append("  string id = 1;\n");
        schema.append("  string name = 2;\n");

        if (version >= 2) {
            schema.append("  string email = 3;\n");
        }

        if (version >= 3) {
            schema.append("  string phone = 4;\n");
            schema.append("  int64 timestamp = 5;\n");
        }

        schema.append("}\n");
        return schema.toString();
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
