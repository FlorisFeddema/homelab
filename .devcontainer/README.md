# Devcontainer credentials

The devcontainer uses dedicated read-only Kubernetes and Talos credentials from
`~/.config/homelab-devcontainer`. It never mounts the administrator kubeconfig or
Talos configuration.

After Argo CD has synced the `devcontainer-users` app, create or rotate the
credentials from a trusted host shell that has administrator `kubectl` and
`talosctl` configuration:

```shell
TALOSCONFIG=~/.talos/config ./.devcontainer/bootstrap-readonly-credentials.sh mba-floris-devcontainer
```

The Argo CD app creates the `homelab-devcontainer` namespace, a Kubernetes
service account for each `users` entry in
`products/ai/devcontainer-users/values.yaml`. Every configured user is bound to
the built-in `view` role and the same selected cluster-scoped read permissions.
The script creates a Talos client certificate with the `os:reader` role and
writes the credential files.

To revoke access permanently, remove the user from
`products/ai/devcontainer-users/values.yaml` and allow Argo CD to prune its
ServiceAccount and token Secret. Deleting the token Secret directly only rotates
the token because Argo CD recreates the Secret; rerun the bootstrap script to
use the replacement credential.
