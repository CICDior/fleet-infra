# Simple test cluster for some rbac testing

## Authentication / Authorization
The cluster is created using a static token file for authentication: [token-auth-file.csv](./install/token-auth-file.csv). This file is mounted 
inside the static pod of the api server. See kind configuration file [here](./kind/kind-local-4.yaml).
Each of the tokens refers to a different user with different roles

## RBAC
The groups listed in the csv file are referenced in the role bindings for the appropriate roles. For example the
user `pod-reader` is part of the group `pod-reader` which in turn is the subject of the role binding `pod-reader-binding`.


## Testing
After cluster installation the user for the current context can be set like this:
```bash
kubectl config set contexts.kind-kind-local-4.user test-user
```
The user token can then be set like this:
```bash
kubectl config set users.test-user.token Token456
```
That token for example would be the token for the user `pod-reader` in the csv file which is allowed to read pods.
Note that the config commands only work if the token has already been added to the kubeconfig file. It should look like this:
```yaml
users:
- name: test-user
  user:
    <token>
```
To test if the impersonation works, try:
```bash
kubectl auth whoami
```
and
```bash
kubectl get pods -A
```
which should return all pots. Contrary to that, the following command should return an error:
```bash
kubectl get configmaps -A
```
