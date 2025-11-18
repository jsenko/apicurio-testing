package io.apicurio.testing.kafka;

import io.apicurio.registry.serde.SerdeConfig;
import io.apicurio.registry.serde.avro.AvroKafkaDeserializer;
import io.apicurio.registry.serde.avro.AvroKafkaSerdeConfig;
import io.apicurio.registry.serde.avro.ReflectAvroDatumProvider;
import io.apicurio.registry.serde.config.IdOption;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Date;
import java.util.Properties;
import java.util.UUID;

/**
 * Kafka Consumer application using Apicurio Registry v2 SerDes.
 * Consumes greeting messages from the 'avro-messages' topic.
 */
public class ConsumerApp {

    private static final String DEFAULT_KAFKA_BOOTSTRAP = "localhost:9092";
    private static final String DEFAULT_REGISTRY_URL = "http://localhost:8080/apis/registry/v2";
    private static final String DEFAULT_TOPIC = "avro-messages";
    private static final int DEFAULT_MAX_MESSAGES = 50;
    private static final int DEFAULT_TIMEOUT_SECONDS = 5;

    public static void main(String[] args) {
        System.out.println("=========================================");
        System.out.println("  Kafka Consumer v2 (Apicurio SerDes)");
        System.out.println("=========================================");

        String kafkaBootstrap = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", DEFAULT_KAFKA_BOOTSTRAP);
        String registryUrl = System.getenv().getOrDefault("REGISTRY_URL", DEFAULT_REGISTRY_URL);
        String topic = System.getenv().getOrDefault("TOPIC_NAME", DEFAULT_TOPIC);
        int maxMessages = Integer.parseInt(System.getenv().getOrDefault("MAX_MESSAGES", String.valueOf(DEFAULT_MAX_MESSAGES)));
        int timeoutSeconds = Integer.parseInt(System.getenv().getOrDefault("TIMEOUT_SECONDS", String.valueOf(DEFAULT_TIMEOUT_SECONDS)));

        System.out.println("Kafka Bootstrap: " + kafkaBootstrap);
        System.out.println("Registry URL: " + registryUrl);
        System.out.println("Topic: " + topic);
        System.out.println("Max Messages: " + maxMessages);
        System.out.println("Timeout: " + timeoutSeconds + " seconds");
        System.out.println("=========================================");
        System.out.println();

        KafkaConsumer<String, GreetingMessage> consumer = createConsumer(kafkaBootstrap, registryUrl);

        try {
            consumeMessages(consumer, topic, maxMessages, timeoutSeconds);
        } catch (Exception e) {
            System.err.println("❌ Error consuming messages: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        } finally {
            consumer.close();
        }
    }

    /**
     * Creates a Kafka consumer configured with Apicurio Registry v2 SerDes.
     *
     * @param kafkaBootstrap Kafka bootstrap servers
     * @param registryUrl Apicurio Registry URL
     * @return configured Kafka consumer
     */
    private static KafkaConsumer<String, GreetingMessage> createConsumer(String kafkaBootstrap, String registryUrl) {
        // Configure SSL truststore for Registry (HTTPS) and Keycloak (OAuth)
        String trustStorePath = System.getenv("TRUSTSTORE_PATH");
        String trustStorePassword = System.getenv().getOrDefault("TRUSTSTORE_PASSWORD", "registry123");

        if (trustStorePath != null && !trustStorePath.isEmpty()) {
            System.setProperty("javax.net.ssl.trustStore", trustStorePath);
            System.setProperty("javax.net.ssl.trustStorePassword", trustStorePassword);
            System.out.println("SSL TrustStore configured: " + trustStorePath);
        }

        Properties props = new Properties();

        // Kafka consumer configuration
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrap);

        // Use unique UUID as group ID to force re-consumption from beginning each time
        String groupId = "kafka-consumer-v2-" + UUID.randomUUID().toString();
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);

        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "true");
        props.put(ConsumerConfig.AUTO_COMMIT_INTERVAL_MS_CONFIG, "1000");
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, AvroKafkaDeserializer.class.getName());

        // Apicurio Registry v2 configuration
        props.put(SerdeConfig.REGISTRY_URL, registryUrl);
        props.put(SerdeConfig.ENABLE_CONFLUENT_ID_HANDLER, "true");
        props.put(SerdeConfig.USE_ID, IdOption.contentId.name());

        // OAuth2 configuration for Registry (if credentials provided)
        String clientId = System.getenv("OAUTH_CLIENT_ID");
        String clientSecret = System.getenv("OAUTH_CLIENT_SECRET");
        String authServerUrl = System.getenv("OAUTH_SERVER_URL");
        String realm = System.getenv("OAUTH_REALM");

        if (clientId != null && clientSecret != null && authServerUrl != null && realm != null) {
            props.put(SerdeConfig.AUTH_SERVICE_URL, authServerUrl);
            props.put(SerdeConfig.AUTH_REALM, realm);
            props.put(SerdeConfig.AUTH_CLIENT_ID, clientId);
            props.put(SerdeConfig.AUTH_CLIENT_SECRET, clientSecret);
            System.out.println("OAuth2 authentication configured (realm: " + realm + ")");
        }

        // Use Java reflection as the Avro Datum Provider
        props.put(AvroKafkaSerdeConfig.AVRO_DATUM_PROVIDER, ReflectAvroDatumProvider.class.getName());

        return new KafkaConsumer<>(props);
    }

    /**
     * Consumes greeting messages from the specified topic.
     *
     * @param consumer Kafka consumer
     * @param topic topic name
     * @param maxMessages maximum number of messages to consume
     * @param timeoutSeconds timeout in seconds
     */
    private static void consumeMessages(KafkaConsumer<String, GreetingMessage> consumer, String topic, int maxMessages, int timeoutSeconds) {
        System.out.println("Subscribing to topic: " + topic);
        consumer.subscribe(Collections.singletonList(topic));
        System.out.println("Waiting for messages (max: " + maxMessages + ", timeout: " + timeoutSeconds + "s)...");
        System.out.println();

        int messageCount = 0;
        long startTime = System.currentTimeMillis();
        long timeoutMillis = timeoutSeconds * 1000L;
        boolean timeoutReached = false;

        while (messageCount < maxMessages && !timeoutReached) {
            ConsumerRecords<String, GreetingMessage> records = consumer.poll(Duration.ofSeconds(1));

            if (records.isEmpty()) {
                // Check if timeout reached
                long elapsed = System.currentTimeMillis() - startTime;
                if (elapsed >= timeoutMillis) {
                    timeoutReached = true;
                    System.out.println("⏱️  Timeout reached (" + timeoutSeconds + "s), stopping...");
                }
                continue;
            }

            records.forEach(record -> {
                GreetingMessage message = record.value();
                System.out.printf("  ✓ [Partition %d, Offset %d] Key: %s, Message: %s, Timestamp: %s%n",
                    record.partition(),
                    record.offset(),
                    record.key(),
                    message.getMessage(),
                    new Date(message.getTimestamp())
                );
            });

            messageCount += records.count();

            // Reset timeout timer when messages are received
            startTime = System.currentTimeMillis();
        }

        System.out.println();
        System.out.println("=========================================");
        if (messageCount >= maxMessages) {
            System.out.println("✅ Consumed maximum number of messages: " + messageCount);
        } else if (timeoutReached) {
            System.out.println("✅ Consumed " + messageCount + " messages (timeout reached)");
        } else {
            System.out.println("✅ Consumed " + messageCount + " messages");
        }
        System.out.println("=========================================");
    }
}
