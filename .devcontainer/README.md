# Devcontainer credentials

The devcontainer uses dedicated read-only Kubernetes and Talos credentials from
`~/.config/homelab-devcontainer`. It never mounts the administrator kubeconfig or
Talos configuration.

## Argo CD

The `argocd` command runs in core mode using the mounted read-only Kubernetes
credentials. This lets it inspect Argo CD Applications without an Argo CD API
token:

```shell
argocd app list
argocd app get <application>
```

Write operations, including application syncs, remain denied by Kubernetes RBAC.
To authenticate to the Argo CD API directly, use
`/usr/local/bin/argocd-real`.

## Grafana MCP

The credential bootstrap generates Copilot CLI configuration for the read-only
Grafana MCP server. The devcontainer exposes it at
`~/.copilot/mcp-config.json`, so Copilot discovers the server automatically:

```shell
copilot mcp get grafana
```

The API key is unique to the configured devcontainer user. Removing that user
from `auth.clients` in `products/ai/grafana-mcp-server/values.yaml` revokes its
Grafana MCP access after Argo CD syncs the change.

## Credential bootstrap

After Argo CD has synced the `devcontainer-users` and `grafana-mcp-server`
apps, create or rotate the credentials from a trusted host shell that has
administrator `kubectl` and `talosctl` configuration:

```shell
TALOSCONFIG=~/.talos/config ./.devcontainer/bootstrap-readonly-credentials.sh mba-floris-devcontainer
```

The Argo CD apps create the `homelab-devcontainer` namespace, a Kubernetes
service account for each `users` entry in
`products/ai/devcontainer-users/values.yaml`. Every configured user is bound to
the built-in `view` role and the same selected cluster-scoped read permissions.
The Grafana MCP chart creates a matching API key for each `auth.clients` entry
in `products/ai/grafana-mcp-server/values.yaml`. The script also creates a Talos
client certificate with the `os:reader` role and writes the credential files.

To revoke all access permanently, remove the user from both product values
files and allow Argo CD to reconcile the changes. Deleting the Kubernetes token
Secret directly only rotates that token because Argo CD recreates the Secret;
rerun the bootstrap script to use replacement credentials.
