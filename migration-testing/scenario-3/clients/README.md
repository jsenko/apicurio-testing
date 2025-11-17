# Java Client Applications

This directory contains Java client applications for creating and validating test data in Apicurio Registry.

## Applications

### 1. artifact-creator

**Purpose**: Creates comprehensive test data in Apicurio Registry using the v2 API.

**Creates**:
- 10 Avro schemas (3-5 versions each)
- 5 Protobuf schemas (2-3 versions each)
- 5 JSON schemas (2-3 versions each)
- 3 OpenAPI specifications (2 versions each)
- 2 AsyncAPI specifications (2 versions each)
- Global rules (VALIDITY, COMPATIBILITY)
- Artifact-specific rules

**Total**: 25 artifacts, ~75 versions

**Location**: `artifact-creator/`

**Main Class**: `io.apicurio.testing.creator.ArtifactCreatorApp`

**Usage**:
```bash
java -jar artifact-creator/target/artifact-creator-1.0.0-SNAPSHOT.jar \
  [registry-url] \
  [output-file]
```

**Arguments**:
- `registry-url` - URL of the registry (default: `http://localhost:8080/apis/registry/v2`)
- `output-file` - Path to write creation summary (default: `data/creation-summary.txt`)

**Example**:
```bash
java -jar artifact-creator/target/artifact-creator-1.0.0-SNAPSHOT.jar \
  http://localhost:8080/apis/registry/v2 \
  ../data/creation-summary.txt
```

### 2. artifact-validator-v2

**Purpose**: Validates all artifacts in Apicurio Registry using the v2 API.

**Validates**:
- Artifact counts (total and by type)
- Version counts
- Metadata (labels, properties, descriptions)
- Global rules (VALIDITY, COMPATIBILITY)
- Artifact-specific rules
- Content retrieval (by globalId and contentId)

**Location**: `artifact-validator-v2/`

**Main Class**: `io.apicurio.testing.validator.ArtifactValidatorApp`

**Usage**:
```bash
java -jar artifact-validator-v2/target/artifact-validator-v2-1.0.0-SNAPSHOT.jar \
  [registry-url] \
  [output-file]
```

**Arguments**:
- `registry-url` - URL of the registry (default: `http://localhost:8080/apis/registry/v2`)
- `output-file` - Path to write validation report (default: `data/validation-report-v2.txt`)

**Example**:
```bash
java -jar artifact-validator-v2/target/artifact-validator-v2-1.0.0-SNAPSHOT.jar \
  http://localhost:8080/apis/registry/v2 \
  ../data/validation-report-v2.txt
```

**Exit Codes**:
- `0` - All validations passed
- `1` - Some validations failed
- `2` - Error during validation

## Building and Running

Both applications are configured with the `maven-exec-plugin` to automatically run after building.

### Build and Run with Default Settings

**artifact-creator**:
```bash
cd artifact-creator
mvn clean package
```

This will:
1. Clean previous builds
2. Compile and package the application
3. Run the application with default settings:
   - Registry URL: `http://localhost:8080/apis/registry/v2`
   - Output file: `../../data/creation-summary.txt`
   - Log level: `info`

**artifact-validator-v2**:
```bash
cd artifact-validator-v2
mvn clean package
```

This will:
1. Clean previous builds
2. Compile and package the application
3. Run the application with default settings:
   - Registry URL: `http://localhost:8080/apis/registry/v2`
   - Output file: `../../data/validation-report-v2.txt`
   - Log level: `info`

### Build and Run with Custom Settings

Override default properties using `-D` flags:

**artifact-creator with custom settings**:
```bash
cd artifact-creator
mvn clean package \
  -Dregistry.url=http://localhost:2222/apis/registry/v2 \
  -Doutput.file=/tmp/my-summary.txt \
  -Dlog.level=debug
```

**artifact-validator-v2 with custom settings**:
```bash
cd artifact-validator-v2
mvn clean package \
  -Dregistry.url=http://localhost:2222/apis/registry/v2 \
  -Doutput.file=/tmp/my-report.txt \
  -Dlog.level=debug
```

### Build Only (Skip Execution)

To build without running the application:
```bash
mvn clean package -Dexec.skip=true
```

### Build All Clients (Script)

Use the provided build script to build both applications without running them:
```bash
cd ..
./scripts/build-clients.sh
```

This script builds both JAR files without executing the applications.

## Maven Properties

Both applications support the following Maven properties for customization:

### artifact-creator

| Property | Default Value | Description |
|----------|---------------|-------------|
| `registry.url` | `http://localhost:8080/apis/registry/v2` | URL of the Apicurio Registry |
| `output.file` | `../../data/creation-summary.txt` | Path to write creation summary |
| `log.level` | `info` | Logging level (trace, debug, info, warn, error) |

### artifact-validator-v2

| Property | Default Value | Description |
|----------|---------------|-------------|
| `registry.url` | `http://localhost:8080/apis/registry/v2` | URL of the Apicurio Registry |
| `output.file` | `../../data/validation-report-v2.txt` | Path to write validation report |
| `log.level` | `info` | Logging level (trace, debug, info, warn, error) |

## Requirements

- Java 11 or later
- Maven 3.6 or later
- Apicurio Registry running and accessible

## Dependencies

Both applications use:
- Apicurio Registry Client 2.6.13.Final
- Apicurio Registry Utils 2.6.13.Final
- Jackson 2.15.2
- SLF4J 1.7.36

## Project Structure

```
clients/
├── artifact-creator/
│   ├── pom.xml
│   └── src/main/java/io/apicurio/testing/creator/
│       ├── ArtifactCreatorApp.java          # Main application
│       ├── model/
│       │   └── CreationSummary.java         # Summary model
│       └── generators/
│           ├── AvroSchemaGenerator.java     # Avro schema generator
│           ├── ProtobufSchemaGenerator.java # Protobuf generator
│           ├── JsonSchemaGenerator.java     # JSON schema generator
│           ├── OpenApiGenerator.java        # OpenAPI generator
│           └── AsyncApiGenerator.java       # AsyncAPI generator
│
└── artifact-validator-v2/
    ├── pom.xml
    └── src/main/java/io/apicurio/testing/validator/
        ├── ArtifactValidatorApp.java        # Main application
        ├── model/
        │   └── ValidationReport.java        # Report model
        └── validators/
            ├── ArtifactCountValidator.java  # Count validation
            ├── MetadataValidator.java       # Metadata validation
            ├── RuleValidator.java           # Rule validation
            └── ContentValidator.java        # Content retrieval validation
```

## Integration with Migration Testing

These applications are used in Steps C and D of the migration testing scenario:

**Step C** (`scripts/step-C-create-data.sh`):
- Runs artifact-creator
- Populates registry with test data
- Saves creation summary

**Step D** (`scripts/step-D-validate-pre-migration.sh`):
- Runs artifact-validator-v2
- Validates all test data
- Saves validation report
- Exits with error if validation fails

## Logging

Both applications use SLF4J with simple logging. Log level can be configured via system property:
```bash
java -Dorg.slf4j.simpleLogger.defaultLogLevel=debug -jar ...
```

Available log levels: `trace`, `debug`, `info`, `warn`, `error`

## Troubleshooting

### Build Failures

**Issue**: Maven build fails with compilation errors

**Solution**: Ensure Java 11+ is being used:
```bash
java -version
mvn -version
```

### Connection Failures

**Issue**: Cannot connect to registry

**Solution**:
1. Verify registry is running: `curl http://localhost:8080/apis/registry/v2/system/info`
2. Check URL is correct (should end with `/apis/registry/v2`)
3. Ensure nginx is running and routing correctly

### Validation Failures

**Issue**: validator reports failures

**Solution**:
1. Check creation summary to see what was created
2. Review validation report for specific failures
3. Ensure Step C completed successfully before running Step D
4. Verify registry hasn't been modified between steps

## Future Enhancements

Potential improvements for future versions:
- Artifact references (schemas with $ref, imports)
- More complex version compatibility scenarios
- Performance benchmarking
- Parallel artifact creation
- Configurable test data sizes
- Support for additional artifact types
