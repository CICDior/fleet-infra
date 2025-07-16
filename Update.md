# Update
This document describes the process of updating components in one of the clusters or the infrastructure.

## Updating Components
For tools to use see [Regression Testing](RegressionTest.md#commands-to-use).
1. Get the latest version of the component you want to update from Github or another source.
1. **Download and compare values.yaml files** - Before updating, download the values.yaml from both the current and target versions to identify potential breaking changes. For example to update the `trivy-operator` from version `0.25.0` to `0.29.3`, you would run:
   ```bash
   curl -s https://raw.githubusercontent.com/aquasecurity/trivy-operator/v0.25.0/deploy/helm/values.yaml > /tmp/values-old.yaml
   curl -s https://raw.githubusercontent.com/aquasecurity/trivy-operator/v0.29.3/deploy/helm/values.yaml > /tmp/values-new.yaml
   diff -u /tmp/values-old.yaml /tmp/values-new.yaml
   ```
1. Analyze the changes and determine if they are compatible with the current version used. Pay special attention to:
   - Configuration option changes or removals
   - Default value changes that might affect existing setups
   - New required fields or deprecated fields
1. **Check current configuration** - Review existing custom values files (e.g., `trivy-additional-values.yaml`) to ensure compatibility with the new version.
1. If the changes are compatible, update the component in the cluster.
1. If the changes are not compatible, you may need to modify the values for the component or the cluster configurations to accommodate the new version.
1. Commit the changes to the repository with a clear but concise message about what was updated and why.
1. Push the changes to the repository in order to be picked up by the following steps.
1. Test the updated component by running the regression tests as described in [Regression Testing](RegressionTest.md#regression-testing-steps) for each cluster.
1. After testing, create a tag for the updated component in the repository.