package io.apicurio.testing.kafka;

import io.apicurio.registry.serde.avro.AvroKafkaSerializer;
import io.apicurio.registry.serde.avro.AvroSerdeConfig;
import io.apicurio.registry.serde.avro.ReflectAvroDatumProvider;
import io.apicurio.registry.serde.config.SerdeConfig;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

/**
 * Kafka Producer application using Apicurio Registry v3 SerDes.
 * Produces greeting messages to the 'avro-messages' topic.
 */
public class ProducerApp {

    private static final String DEFAULT_KAFKA_BOOTSTRAP = "localhost:9092";
    private static final String DEFAULT_REGISTRY_URL = "http://localhost:8080/apis/registry/v3";
    private static final String DEFAULT_TOPIC = "avro-messages";
    private static final int DEFAULT_MESSAGE_COUNT = 10;

    public static void main(String[] args) {
        String kafkaBootstrap = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", DEFAULT_KAFKA_BOOTSTRAP);
        String registryUrl = System.getenv().getOrDefault("REGISTRY_URL", DEFAULT_REGISTRY_URL);
        String topic = System.getenv().getOrDefault("TOPIC_NAME", DEFAULT_TOPIC);
        int messageCount = Integer.parseInt(System.getenv().getOrDefault("MESSAGE_COUNT", String.valueOf(DEFAULT_MESSAGE_COUNT)));

        System.out.println("=========================================");
        System.out.println("  Kafka Producer v3 (Apicurio SerDes)");
        System.out.println("=========================================");
        System.out.println("Kafka Bootstrap: " + kafkaBootstrap);
        System.out.println("Registry URL: " + registryUrl);
        System.out.println("Topic: " + topic);
        System.out.println("Message Count: " + messageCount);
        System.out.println("=========================================");
        System.out.println();

        Producer<String, GreetingMessage> producer = createProducer(kafkaBootstrap, registryUrl);

        try {
            produceMessages(producer, topic, messageCount);
            System.out.println();
            System.out.println("✅ Successfully produced " + messageCount + " messages");
        } catch (Exception e) {
            System.err.println("❌ Error producing messages: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        } finally {
            producer.flush();
            producer.close();
        }
    }

    /**
     * Creates a Kafka producer configured with Apicurio Registry v3 SerDes.
     *
     * @param kafkaBootstrap Kafka bootstrap servers
     * @param registryUrl Apicurio Registry URL
     * @return configured Kafka producer
     */
    private static Producer<String, GreetingMessage> createProducer(String kafkaBootstrap, String registryUrl) {
        Properties props = new Properties();

        // Kafka producer configuration
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrap);
        props.put(ProducerConfig.CLIENT_ID_CONFIG, "kafka-producer-v3");
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroKafkaSerializer.class.getName());

        // Apicurio Registry v3 configuration
        props.put(SerdeConfig.REGISTRY_URL, registryUrl);
        props.put(SerdeConfig.AUTO_REGISTER_ARTIFACT, Boolean.TRUE);

        // Use Java reflection as the Avro Datum Provider
        // This generates an Avro schema from the GreetingMessage Java bean
        props.put(AvroSerdeConfig.AVRO_DATUM_PROVIDER, ReflectAvroDatumProvider.class.getName());

        return new KafkaProducer<>(props);
    }

    /**
     * Produces greeting messages to the specified topic.
     *
     * @param producer Kafka producer
     * @param topic topic name
     * @param count number of messages to produce
     */
    private static void produceMessages(Producer<String, GreetingMessage> producer, String topic, int count) throws Exception {
        System.out.println("Producing " + count + " messages...");
        System.out.println();

        for (int i = 1; i <= count; i++) {
            String key = "key-" + i;
            GreetingMessage message = new GreetingMessage(
                "Hello from producer-v3! Message #" + i,
                System.currentTimeMillis()
            );

            ProducerRecord<String, GreetingMessage> record = new ProducerRecord<>(topic, key, message);

            producer.send(record, (metadata, exception) -> {
                if (exception != null) {
                    System.err.println("  ❌ Error sending message " + key + ": " + exception.getMessage());
                } else {
                    System.out.println("  ✓ Sent message " + key + " to partition " + metadata.partition() + " at offset " + metadata.offset());
                }
            }).get(); // Wait for send to complete

            // Small delay between messages
            Thread.sleep(100);
        }
    }
}
