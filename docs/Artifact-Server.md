# Artifact Server

The Artifact Server is an OCP cluster with additional applications and services installed. It is needed because some tests require artifacts that are not accessible from the public internet. The Artifact Server provides these artifacts to the tests.

There are currently two applications being installed on the Artifact Server:

 1. Docker Registry - Used to install the operator using OLM.
 2. Sharry - Used to host files, such as the offline maven repository.
