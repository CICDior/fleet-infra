# Update
This document describes the process of updating components in one of the clusters or the infrastructure.

## Updating Components
For tools to use see [Regression Testing](RegressionTest.md#commands-to-use).
1. Get the latest version of the component you want to update from Github or another source.
2. Analyze the changes and determine if they are compatible with the current version used.
3. If the changes are compatible, update the component in the cluster.
4. If the changes are not compatible, you may need to modify the values for the component or the cluster configurations to accommodate the new version.
5. Commit the changes to the repository with a clear but concise message about what was updated and why.
6. Test the updated component to ensure it works as expected. Finally running the install.sh script in the cluster directory.
