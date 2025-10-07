# Operator Testing Guide

1. Provision the artifact server using GitHub workflow.
2. Log in to the VPN.
3. Modify and upload index images to the artifact server using the provided script:
   ```bash
   ./install-index-image.sh --cluster art --image registry-proxy.engineering.redhat.com/rh-osbs/iib:1234567
   ```
   ```
   [...]
   [Success] Image image-registry-infra.apps.art.apicurio-testing.org/rh-osbs/iib:1234567 has been pushed to the registry.
   ```
   Each OCP version used for testing requires a corresponding index image.
4. Run the OLM tests workflow. Provide the new index image URI.
