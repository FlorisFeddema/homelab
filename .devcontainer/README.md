# Devcontainer credentials

The devcontainer uses dedicated read-only Kubernetes and Talos credentials from
`~/.config/homelab-devcontainer`. It never mounts the administrator kubeconfig or
Talos configuration.

## GoLand and GitHub Copilot

The container includes Go 1.27 and the JetBrains GitHub Copilot plugin. Open the
repository in GoLand using **Remote Development** > **Dev Containers**, then
select this devcontainer configuration. GoLand installs the Copilot plugin
automatically; sign in through the Copilot tool window after the remote IDE
starts.

## Argo CD

Use the `--core` flag with the `argocd` command to use the mounted read-only
Kubernetes credentials. This lets it inspect Argo CD Applications without an
Argo CD API token:

```shell
argocd --core app list
argocd --core app get <application>
```

Write operations, including application syncs, remain denied by Kubernetes RBAC.

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

## GitHub Copilot CLI

The devcontainer includes the GitHub Copilot CLI. Start it with:

```shell
copilot
```

Authenticate with `/login` when prompted. This stores your GitHub credentials
in the container user’s home directory; credentials are intentionally not
baked into the image or mounted from the host. For non-interactive use, set
`GH_TOKEN` or `GITHUB_TOKEN` to a fine-grained token with the **Copilot
Requests** permission.

After the credential bootstrap has run, verify that Copilot can see Grafana:

```shell
copilot mcp get grafana
```

The bootstrap writes the generated read-only Grafana API key to
`~/.config/homelab-devcontainer/mcp-config.json`, which the container exposes
as `~/.copilot/mcp-config.json`.

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
