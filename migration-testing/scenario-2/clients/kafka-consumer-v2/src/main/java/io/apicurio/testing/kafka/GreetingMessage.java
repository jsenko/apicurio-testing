package io.apicurio.testing.kafka;

/**
 * Simple POJO representing a greeting message.
 * This class will be serialized to Avro using reflection.
 */
public class GreetingMessage {

    private String message;
    private long timestamp;

    /**
     * Default constructor required for Avro reflection.
     */
    public GreetingMessage() {
    }

    /**
     * Constructor with parameters.
     *
     * @param message the greeting message
     * @param timestamp the message timestamp
     */
    public GreetingMessage(String message, long timestamp) {
        this.message = message;
        this.timestamp = timestamp;
    }

    /**
     * Gets the greeting message.
     *
     * @return the message
     */
    public String getMessage() {
        return message;
    }

    /**
     * Sets the greeting message.
     *
     * @param message the message to set
     */
    public void setMessage(String message) {
        this.message = message;
    }

    /**
     * Gets the message timestamp.
     *
     * @return the timestamp
     */
    public long getTimestamp() {
        return timestamp;
    }

    /**
     * Sets the message timestamp.
     *
     * @param timestamp the timestamp to set
     */
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return "GreetingMessage{message='" + message + "', timestamp=" + timestamp + "}";
    }
}
