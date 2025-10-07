# Extra Tests

This document outlines additional tests that can be performed for the RBOAR release:

## 1. Test that all artifacts in the offline repo are in MRRC

```bash
./test-artifacts-are-in-mrrc.sh --file apicurio-registry-3.1.0.GA-maven-repository.zip --force
```

## 2. Test that the install files are correct.

```bash
./test-install-examples.sh --cluster qe419 --file ./apicurio-registry-3.1.0.GA-install-examples.zip --force
```
