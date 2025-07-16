# Regression Testing
For a general description of the repository and its purpose, see the [README](README.md).

## Commands to Use
- Standard linux commands
- kubectl
- helm
- kustomize
- kind
- flux
- podman
- gh (github CLI)
- git

## Regression Testing Steps
For each cluster in `clusters/staging`:
- Delete the cluster using `kind delete cluster --name <cluster-name>`
- Run `install.sh` in the subfolder install to create a new cluster
- If install.sh does not yield any errors, the test is successful
- If not analyze the cause of the error. For some useful commands see [Common troubleshooting steps](#common-troubleshooting-steps)
- If you can not fix the error, create an issue in the repository with:
    - A concise description of the error
    - A comprehensive and brief description of things you tried to analyze and fix the error
    - Any relevant logs or output
- Delete the cluster using `kind delete cluster --name <cluster-name>`
Special note: There are Kustomizations and GitRepositories that reference the repository `secrets`. Do not attempt to read or modify the contents of this repository. If the problem is related to the secrets, create an issue in the repository.

## Common troubleshooting steps
- Look at the status of flux kustomizations / git repositories and helm charts k8s objects
- Check the status of pods, deployment
- Analyze logs of the pods
- Look at the events
- `Exec` into the pods to furher analyze
- `Exec` into the nodes of the cluster to analyze the problem there. Possible commands:
  - `journalctl -u kubelet`
  - `journalctl -u containerd`
  - `systemctl status kubelet`
  - `systemctl status containerd`
- Use git to look at the latest changes in the repository that might have caused the issue