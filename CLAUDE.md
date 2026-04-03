# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This repo manages `gerador`, a Talos-based Kubernetes homelab deployed GitOps-style with Argo CD. Three concerns:

- **`talos/`** — Talos OS machine configuration for all nodes
- **`chart/`** — Top-level Helm chart that renders Argo CD `Application` objects (app-of-apps)
- **`products/`** — Individual Helm charts for each workload, synced by Argo CD

## Deployment Model

`chart/values.yaml` is the single authoritative inventory of what is deployed. Argo CD bootstraps by syncing `chart/`, which renders one `Application` per enabled product entry. Each application points at `products/<group>/<product>/` in this repo at HEAD.

A directory existing under `products/` does **not** mean it is active — only products with `deploy: true` in `chart/values.yaml` are part of the live cluster.

Product names in `chart/values.yaml` are camelCase; they map to kebab-case directory names under `products/<group>/`. The group key also kebab-cases when forming the path (e.g. `deviceOperators` → `products/device-operators/`).

## Common Commands

### Helm

```shell
# Preview rendered Argo CD Application manifests
helm template chart/ --values chart/values.yaml

# Lint a product chart
helm lint products/<group>/<product>/
```

### Sealed Secrets

```shell
# Seal a secret manifest
kubeseal --controller-namespace sealed-secrets -o yaml < secret.yaml > sealed-secret.yaml

# Seal a single raw value (namespace-scoped)
echo -n '<VALUE>' | kubeseal --controller-namespace sealed-secrets --raw --namespace <NAMESPACE> --name <NAME>
```

### Talos (run from inside `talos/`)

Scripts use relative paths (`./rendered/`, `./secrets.yaml`) so they must be run from `talos/`.

```shell
cd talos

# Apply updated config to one node
sh ./update-config.sh -n <node>
sh ./update-config.sh -n <node> -d true          # dry-run

# Apply updated config to all nodes (60s delay between each)
sh ./update-all-config.sh -s 60
sh ./update-all-config.sh -d true -s 60          # dry-run

# Bootstrap a new node (insecure apply, before the node has joined)
sh ./create-node.sh -n <node> -t worker -i <IP>
sh ./create-node.sh -n <node> -t worker -i <IP> -d true  # dry-run

# Upgrade Talos version on a node
sh ./update-talos.sh -n <node> -v <version>
```

After a new node has joined the cluster, run `update-config.sh` on it to switch to the day-2 patch workflow.

### Misc Kubernetes

```shell
# Delete all zero-replica ReplicaSets
kubectl get replicaset -A -o jsonpath='{range .items[?(@.spec.replicas==0)]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
  | while read -r namespace name; do
      [ -n "$namespace" ] && kubectl delete replicaset -n "$namespace" "$name"
    done
```

## Architecture Details

### Product Charts (`products/<group>/<product>/`)

Each chart typically contains:
- `Chart.yaml` — may declare upstream Helm chart as a dependency and/or `gatus-monitor` from `templates/`
- `values.yaml` — configuration overrides for the upstream chart
- `templates/` — cluster-specific manifests (CRDs, SealedSecrets, HTTPRoutes, etc.)
- `dashboards/` — Grafana dashboard ConfigMaps (for monitoring-instrumented products)

### Shared Dependencies (`templates/`)

`templates/gatus-monitor/` is a local chart used as a dependency by products that expose a health-check endpoint to Gatus.

### Talos Node Configuration

Each node has two files in `talos/nodes/`:
- `<node>.yaml` — base config: role, labels, install disk
- `<node>-patch.yaml` — host/network specifics: hostname, VIPs, DHCP, extra interfaces

The scripts merge these with `talos/cluster.yaml`, `talos/controlplane.yaml` or `talos/worker.yaml`, and `talos/cluster-patch.yaml` to produce rendered configs written to `talos/rendered/` (git-ignored).

### Secret Management

All secrets in product charts are `SealedSecret` resources. The controller key secret is named `sealed-secrets-key` in the `sealed-secrets` namespace. To restore it in a new cluster:

```shell
kubectl get secret sealed-secrets-key -n sealed-secrets -o yaml \
  | yq 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.managedFields)' \
  > sealed-secrets-key.yaml
kubectl apply -f sealed-secrets-key.yaml
kubectl rollout restart -n sealed-secrets deployment sealed-secrets-controller
rm sealed-secrets-key.yaml
```

### Registry Mirrors

All container images pull through Harbor at `harbor.feddema.dev`, which mirrors `docker.io`, `ghcr.io`, `registry.k8s.io`, `quay.io`, `public.ecr.aws`, `mirror.gcr.io`, and `reg.kyverno.io`. This is configured in `talos/cluster-patch.yaml`.

### Argo CD Projects

- `always-sync` — used when `autoSync: true`; Argo CD will auto-sync, prune, and self-heal
- `no-sync` — used when `autoSync: false`; sync must be triggered manually

### Adding a New Product

1. Copy `products/_base/` to `products/<group>/<product>/`
2. Add an entry under the correct group in `chart/values.yaml` with at minimum `deploy: true` and `autoSync: true/false`
3. The Argo CD Application is automatically rendered; the product directory name must match the camelCase key kebab-cased

## Cluster Reference

- Cluster name: `gerador`
- Control plane endpoint: `https://gerador.feddema.dev:6443`
- 3 control-plane nodes + 6 worker nodes (see `talos/nodes/`)
- Required local CLIs: `helm`, `kubectl`, `talosctl`, `kubeseal`, `yq`
