package io.apicurio.testing.creator.generators;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
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
 * Generates OpenAPI specification artifacts for testing.
 * Creates 3 artifacts with 2 versions each.
 */
public class OpenApiGenerator {

    private static final Logger log = LoggerFactory.getLogger(OpenApiGenerator.class);
    private static final ObjectMapper mapper = new ObjectMapper();

    private final RegistryClient client;
    private final CreationSummary summary;

    public OpenApiGenerator(RegistryClient client, CreationSummary summary) {
        this.client = client;
        this.summary = summary;
    }

    /**
     * Creates all OpenAPI specification test artifacts.
     */
    public void createArtifacts() throws Exception {
        log.info("Creating OpenAPI specification artifacts...");

        // Create 3 OpenAPI specs with 2 versions each
        for (int i = 1; i <= 3; i++) {
            String artifactId = "openapi-spec-" + i;
            createOpenApiArtifact(artifactId, i, 2);
        }
    }

    /**
     * Creates a single OpenAPI artifact with multiple versions.
     *
     * @param artifactId artifact identifier
     * @param index artifact index for uniqueness
     * @param versionCount number of versions to create
     */
    private void createOpenApiArtifact(String artifactId, int index, int versionCount) throws Exception {
        log.info("  Creating artifact: {} ({} versions)", artifactId, versionCount);

        // Version 1: Base OpenAPI spec
        String spec1 = createBaseOpenApiSpec("API " + index, "1.0.0");
        ArtifactMetaData meta = client.createArtifact(
            "default",
            artifactId,
            ArtifactType.OPENAPI,
            new ByteArrayInputStream(spec1.getBytes(StandardCharsets.UTF_8))
        );

        // Add labels and properties
        EditableMetaData editMeta = new EditableMetaData();
        editMeta.setName(artifactId);
        editMeta.setDescription("OpenAPI test specification #" + index);
        editMeta.setLabels(createLabels("openapi"));
        editMeta.setProperties(createProperties());
        client.updateArtifactMetaData("default", artifactId, editMeta);

        // Create additional versions
        for (int v = 2; v <= versionCount; v++) {
            String spec = createVersionedOpenApiSpec("API " + index, "1." + (v - 1) + ".0");
            client.createArtifactVersion(
                "default",
                artifactId,
                null,
                new ByteArrayInputStream(spec.getBytes(StandardCharsets.UTF_8))
            );
        }

        summary.recordArtifact("OPENAPI", artifactId, versionCount);
        log.info("    ✓ Created {} with {} versions", artifactId, versionCount);
    }

    /**
     * Creates a base OpenAPI 3.0 specification.
     *
     * @param title API title
     * @param version API version
     * @return OpenAPI specification as JSON string
     */
    private String createBaseOpenApiSpec(String title, String version) throws Exception {
        ObjectNode spec = mapper.createObjectNode();
        spec.put("openapi", "3.0.0");

        ObjectNode info = spec.putObject("info");
        info.put("title", title);
        info.put("version", version);
        info.put("description", "Test REST API specification");

        ObjectNode paths = spec.putObject("paths");

        // GET /items
        ObjectNode getItems = paths.putObject("/items").putObject("get");
        getItems.put("summary", "List all items");
        getItems.put("operationId", "listItems");

        ObjectNode getResponses = getItems.putObject("responses");
        ObjectNode get200 = getResponses.putObject("200");
        get200.put("description", "Successful response");

        // POST /items
        ObjectNode postItems = paths.putObject("/items").putObject("post");
        postItems.put("summary", "Create an item");
        postItems.put("operationId", "createItem");

        ObjectNode postResponses = postItems.putObject("responses");
        ObjectNode post201 = postResponses.putObject("201");
        post201.put("description", "Item created");

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(spec);
    }

    /**
     * Creates a versioned OpenAPI specification with additional endpoints.
     *
     * @param title API title
     * @param version API version
     * @return OpenAPI specification as JSON string
     */
    private String createVersionedOpenApiSpec(String title, String version) throws Exception {
        ObjectNode spec = mapper.createObjectNode();
        spec.put("openapi", "3.0.0");

        ObjectNode info = spec.putObject("info");
        info.put("title", title);
        info.put("version", version);
        info.put("description", "Test REST API specification - Updated");

        ObjectNode paths = spec.putObject("paths");

        // GET /items
        ObjectNode itemsPath = paths.putObject("/items");
        ObjectNode getItems = itemsPath.putObject("get");
        getItems.put("summary", "List all items");
        getItems.put("operationId", "listItems");
        ObjectNode getResponses = getItems.putObject("responses");
        getResponses.putObject("200").put("description", "Successful response");

        // POST /items
        ObjectNode postItems = itemsPath.putObject("post");
        postItems.put("summary", "Create an item");
        postItems.put("operationId", "createItem");
        ObjectNode postResponses = postItems.putObject("responses");
        postResponses.putObject("201").put("description", "Item created");

        // GET /items/{id} - New in v2
        ObjectNode itemIdPath = paths.putObject("/items/{id}");
        ObjectNode getItem = itemIdPath.putObject("get");
        getItem.put("summary", "Get item by ID");
        getItem.put("operationId", "getItem");

        ArrayNode parameters = getItem.putArray("parameters");
        ObjectNode idParam = parameters.addObject();
        idParam.put("name", "id");
        idParam.put("in", "path");
        idParam.put("required", true);
        ObjectNode idSchema = idParam.putObject("schema");
        idSchema.put("type", "string");

        ObjectNode getItemResponses = getItem.putObject("responses");
        getItemResponses.putObject("200").put("description", "Item found");
        getItemResponses.putObject("404").put("description", "Item not found");

        // DELETE /items/{id} - New in v2
        ObjectNode deleteItem = itemIdPath.putObject("delete");
        deleteItem.put("summary", "Delete item by ID");
        deleteItem.put("operationId", "deleteItem");
        ObjectNode deleteParams = deleteItem.putArray("parameters").addObject();
        deleteParams.put("name", "id");
        deleteParams.put("in", "path");
        deleteParams.put("required", true);
        deleteParams.putObject("schema").put("type", "string");

        ObjectNode deleteResponses = deleteItem.putObject("responses");
        deleteResponses.putObject("204").put("description", "Item deleted");
        deleteResponses.putObject("404").put("description", "Item not found");

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(spec);
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
