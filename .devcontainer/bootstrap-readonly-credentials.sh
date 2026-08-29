#!/usr/bin/env bash

set -euo pipefail

readonly credentials_dir="${DEVCONTAINER_CREDENTIALS_DIR:-"${HOME}/.config/homelab-devcontainer"}"
readonly service_account_namespace="homelab-devcontainer"
readonly grafana_mcp_namespace="grafana-mcp-server"
readonly grafana_mcp_secret_name="grafana-mcp-bearer-auth-secret"
readonly grafana_mcp_url="https://grafana.mcp.feddema.dev/mcp"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <devcontainer-user>" >&2
    exit 1
fi

readonly service_account_name="$1"
readonly token_secret_name="${service_account_name}-token"

if ! command -v kubectl >/dev/null; then
    echo "kubectl is required to create the Kubernetes reader credentials." >&2
    exit 1
fi

if ! command -v talosctl >/dev/null; then
    echo "talosctl is required to create the Talos reader credentials." >&2
    exit 1
fi

if [[ -z "${TALOSCONFIG:-}" ]]; then
    echo "Set TALOSCONFIG to an administrator Talos configuration before running this script." >&2
    exit 1
fi

if [[ ! -f "${TALOSCONFIG}" ]]; then
    echo "TALOSCONFIG does not exist: ${TALOSCONFIG}" >&2
    exit 1
fi

if ! kubectl get namespace "${service_account_namespace}" >/dev/null; then
    echo "The ${service_account_namespace} namespace is not available. Wait for Argo CD to sync the devcontainer-users app." >&2
    exit 1
fi

token=""
for _ in $(seq 1 30); do
    if token="$(kubectl --namespace "${service_account_namespace}" get secret "${token_secret_name}" --output jsonpath='{.data.token}' 2>/dev/null)" && [[ -n "${token}" ]]; then
        break
    fi
    sleep 1
done

if [[ -z "${token}" ]]; then
    echo "Timed out waiting for the service account token secret." >&2
    exit 1
fi

grafana_mcp_key="$(
    kubectl --namespace "${grafana_mcp_namespace}" get secret "${grafana_mcp_secret_name}" \
        --output "jsonpath={.data.${service_account_name}}" 2>/dev/null
)"
if [[ -z "${grafana_mcp_key}" ]]; then
    echo "No Grafana MCP credential exists for ${service_account_name}. Wait for Argo CD to sync the grafana-mcp-server app." >&2
    exit 1
fi

if base64 --decode </dev/null >/dev/null 2>&1; then
    token="$(printf '%s' "${token}" | base64 --decode)"
    grafana_mcp_key="$(printf '%s' "${grafana_mcp_key}" | base64 --decode)"
else
    token="$(printf '%s' "${token}" | base64 -D)"
    grafana_mcp_key="$(printf '%s' "${grafana_mcp_key}" | base64 -D)"
fi

cluster_server="$(kubectl config view --minify --raw --output jsonpath='{.clusters[0].cluster.server}')"
cluster_ca_data="$(kubectl config view --minify --raw --output jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

if [[ -z "${cluster_server}" || -z "${cluster_ca_data}" ]]; then
    echo "The active kubeconfig context must include a server and embedded certificate authority data." >&2
    exit 1
fi

umask 077
mkdir -p "${credentials_dir}"

cat > "${credentials_dir}/kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: gerador
    cluster:
      certificate-authority-data: ${cluster_ca_data}
      server: ${cluster_server}
contexts:
  - name: ${service_account_name}
    context:
      cluster: gerador
      namespace: default
      user: ${service_account_name}
current-context: ${service_account_name}
users:
  - name: ${service_account_name}
    user:
      token: ${token}
EOF

cat > "${credentials_dir}/mcp-config.json" <<EOF
{
  "mcpServers": {
    "grafana": {
      "type": "http",
      "url": "${grafana_mcp_url}",
      "headers": {
        "Authorization": "Bearer ${grafana_mcp_key}"
      },
      "tools": ["*"]
    }
  }
}
EOF

talosctl config new --roles=os:reader "${credentials_dir}/talosconfig"

echo "Read-only Kubernetes, Talos, and Grafana MCP credentials written to ${credentials_dir}."
