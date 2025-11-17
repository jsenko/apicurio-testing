package io.apicurio.testing.creator.generators;

import com.fasterxml.jackson.databind.ObjectMapper;
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
 * Generates AsyncAPI specification artifacts for testing.
 * Creates 2 artifacts with 2 versions each.
 */
public class AsyncApiGenerator {

    private static final Logger log = LoggerFactory.getLogger(AsyncApiGenerator.class);
    private static final ObjectMapper mapper = new ObjectMapper();

    private final RegistryClient client;
    private final CreationSummary summary;

    public AsyncApiGenerator(RegistryClient client, CreationSummary summary) {
        this.client = client;
        this.summary = summary;
    }

    /**
     * Creates all AsyncAPI specification test artifacts.
     */
    public void createArtifacts() throws Exception {
        log.info("Creating AsyncAPI specification artifacts...");

        // Create 2 AsyncAPI specs with 2 versions each
        for (int i = 1; i <= 2; i++) {
            String artifactId = "asyncapi-spec-" + i;
            createAsyncApiArtifact(artifactId, i, 2);
        }
    }

    /**
     * Creates a single AsyncAPI artifact with multiple versions.
     *
     * @param artifactId artifact identifier
     * @param index artifact index for uniqueness
     * @param versionCount number of versions to create
     */
    private void createAsyncApiArtifact(String artifactId, int index, int versionCount) throws Exception {
        log.info("  Creating artifact: {} ({} versions)", artifactId, versionCount);

        // Version 1: Base AsyncAPI spec
        String spec1 = createBaseAsyncApiSpec("Event API " + index, "1.0.0");
        ArtifactMetaData meta = client.createArtifact(
            "default",
            artifactId,
            ArtifactType.ASYNCAPI,
            new ByteArrayInputStream(spec1.getBytes(StandardCharsets.UTF_8))
        );

        // Add labels and properties
        EditableMetaData editMeta = new EditableMetaData();
        editMeta.setName(artifactId);
        editMeta.setDescription("AsyncAPI test specification #" + index);
        editMeta.setLabels(createLabels("asyncapi"));
        editMeta.setProperties(createProperties());
        client.updateArtifactMetaData("default", artifactId, editMeta);

        // Create additional versions
        for (int v = 2; v <= versionCount; v++) {
            String spec = createVersionedAsyncApiSpec("Event API " + index, "1." + (v - 1) + ".0");
            client.createArtifactVersion(
                "default",
                artifactId,
                null,
                new ByteArrayInputStream(spec.getBytes(StandardCharsets.UTF_8))
            );
        }

        summary.recordArtifact("ASYNCAPI", artifactId, versionCount);
        log.info("    ✓ Created {} with {} versions", artifactId, versionCount);
    }

    /**
     * Creates a base AsyncAPI 2.0 specification.
     *
     * @param title API title
     * @param version API version
     * @return AsyncAPI specification as JSON string
     */
    private String createBaseAsyncApiSpec(String title, String version) throws Exception {
        ObjectNode spec = mapper.createObjectNode();
        spec.put("asyncapi", "2.0.0");

        ObjectNode info = spec.putObject("info");
        info.put("title", title);
        info.put("version", version);
        info.put("description", "Test event-driven API specification");

        ObjectNode channels = spec.putObject("channels");

        // user/created channel
        ObjectNode userCreatedChannel = channels.putObject("user/created");
        ObjectNode subscribe = userCreatedChannel.putObject("subscribe");
        subscribe.put("summary", "Subscribe to user creation events");

        ObjectNode message = subscribe.putObject("message");
        message.put("name", "UserCreated");
        message.put("title", "User Created Event");

        ObjectNode payload = message.putObject("payload");
        payload.put("type", "object");

        ObjectNode properties = payload.putObject("properties");
        properties.putObject("userId").put("type", "string");
        properties.putObject("username").put("type", "string");
        properties.putObject("email").put("type", "string");

        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(spec);
    }

    /**
     * Creates a versioned AsyncAPI specification with additional channels.
     *
     * @param title API title
     * @param version API version
     * @return AsyncAPI specification as JSON string
     */
    private String createVersionedAsyncApiSpec(String title, String version) throws Exception {
        ObjectNode spec = mapper.createObjectNode();
        spec.put("asyncapi", "2.0.0");

        ObjectNode info = spec.putObject("info");
        info.put("title", title);
        info.put("version", version);
        info.put("description", "Test event-driven API specification - Updated");

        ObjectNode channels = spec.putObject("channels");

        // user/created channel
        ObjectNode userCreatedChannel = channels.putObject("user/created");
        ObjectNode subscribe1 = userCreatedChannel.putObject("subscribe");
        subscribe1.put("summary", "Subscribe to user creation events");
        ObjectNode message1 = subscribe1.putObject("message");
        message1.put("name", "UserCreated");
        message1.put("title", "User Created Event");
        ObjectNode payload1 = message1.putObject("payload");
        payload1.put("type", "object");
        ObjectNode properties1 = payload1.putObject("properties");
        properties1.putObject("userId").put("type", "string");
        properties1.putObject("username").put("type", "string");
        properties1.putObject("email").put("type", "string");

        // user/updated channel - New in v2
        ObjectNode userUpdatedChannel = channels.putObject("user/updated");
        ObjectNode subscribe2 = userUpdatedChannel.putObject("subscribe");
        subscribe2.put("summary", "Subscribe to user update events");
        ObjectNode message2 = subscribe2.putObject("message");
        message2.put("name", "UserUpdated");
        message2.put("title", "User Updated Event");
        ObjectNode payload2 = message2.putObject("payload");
        payload2.put("type", "object");
        ObjectNode properties2 = payload2.putObject("properties");
        properties2.putObject("userId").put("type", "string");
        properties2.putObject("changes").put("type", "object");
        properties2.putObject("timestamp").put("type", "string").put("format", "date-time");

        // user/deleted channel - New in v2
        ObjectNode userDeletedChannel = channels.putObject("user/deleted");
        ObjectNode subscribe3 = userDeletedChannel.putObject("subscribe");
        subscribe3.put("summary", "Subscribe to user deletion events");
        ObjectNode message3 = subscribe3.putObject("message");
        message3.put("name", "UserDeleted");
        message3.put("title", "User Deleted Event");
        ObjectNode payload3 = message3.putObject("payload");
        payload3.put("type", "object");
        ObjectNode properties3 = payload3.putObject("properties");
        properties3.putObject("userId").put("type", "string");
        properties3.putObject("timestamp").put("type", "string").put("format", "date-time");

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
