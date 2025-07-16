# Update
This document describes the process of updating components in one of the clusters or the infrastructure.

## Updating Components
For tools to use see [Regression Testing](RegressionTest.md#commands-to-use).
1. Get the latest version of the component you want to update from Github or another source.
2. **Download and compare values.yaml files** - Before updating, download the values.yaml from both the current and target versions to identify potential breaking changes:
   ```bash
   curl -s https://raw.githubusercontent.com/aquasecurity/trivy-operator/v0.25.0/deploy/helm/values.yaml > /tmp/values-old.yaml
   curl -s https://raw.githubusercontent.com/aquasecurity/trivy-operator/v0.27.3/deploy/helm/values.yaml > /tmp/values-new.yaml
   diff -u /tmp/values-old.yaml /tmp/values-new.yaml
   ```
3. Analyze the changes and determine if they are compatible with the current version used. Pay special attention to:
   - Configuration option changes or removals
   - Default value changes that might affect existing setups
   - New required fields or deprecated fields
4. **Check current configuration** - Review existing custom values files (e.g., `trivy-additional-values.yaml`) to ensure compatibility with the new version.
5. If the changes are compatible, update the component in the cluster.
6. If the changes are not compatible, you may need to modify the values for the component or the cluster configurations to accommodate the new version.
7. Commit the changes to the repository with a clear but concise message about what was updated and why.
8. Test the updated component by running the regression tests as described in [Regression Testing](RegressionTest.md#regression-testing-steps) for each cluster.
9. After testing, create a tag for the updated component in the repository.