# Homelab

This repository manages `gerador`, a Talos-based Kubernetes homelab.

The cluster is deployed GitOps-style with Argo CD. The top-level chart in `chart/` renders Argo CD `Application` objects, and those applications point at the per-product Helm charts under `products/`. Today, `chart/values.yaml` defines 54 deployable products grouped into `core`, `connectivity`, `development`, `deviceOperators` (kebab-cased on disk as `products/device-operators/`), `home`, `iot`, `media`, `monitoring`, `security`, and `storage`.

Talos provides the node and cluster machine configuration, `templates/` holds shared Helm dependencies, and `unifi/` contains network-related configuration alongside the cluster manifests. Core platform components such as Cilium, CoreDNS, Argo CD, Sealed Secrets, and the rest of the workload stack are then reconciled from this repo by Argo CD.

## Overview

At a high level, this repo is split into three concerns:

- Talos machine configuration in `talos/`
- Argo CD app-of-apps generation in `chart/`
- Individual workload charts in `products/`

The repo is concrete and environment-specific on purpose. Cluster names, domains, node names, and operational commands here reflect the live homelab setup.

## How The Repo Is Organized

- `chart/`
  The top-level Helm chart. It renders one Argo CD `Application` per enabled product entry in `chart/values.yaml`.
- `chart/values.yaml`
  The source of truth for enabled products, target namespaces, sync behavior, and a few Argo CD sync options such as server-side apply and ignore-differences rules.
- `products/<group>/<product>/`
  The per-application Helm charts that Argo CD syncs into the cluster.
- `products/_base/`
  Scaffolding used when creating product charts.
- `templates/`
  Shared dependency charts, such as `templates/gatus-monitor/`.
- `talos/`
  Cluster-wide Talos config, node definitions, and helper scripts for node creation and upgrades.
- `talos/nodes/<node>.yaml`
  Per-node base machine config, including role, labels, and install disk.
- `talos/nodes/<node>-patch.yaml`
  Per-node host and network patch data, such as hostname, VIPs, DHCP config, and extra links.
- `unifi/`
  Additional network-related configuration.

## Deployment Model

Argo CD bootstraps this repo by syncing the top-level `chart/` chart. That chart renders Argo CD `Application` resources from `chart/templates/product-applications.yaml`, and each enabled entry in `chart/values.yaml` maps to a workload chart under `products/<group>/<product>/`.

That means `chart/values.yaml` is the authoritative inventory of what this homelab deploys. A directory existing under `products/` does not automatically mean it is active; only products referenced in `chart/values.yaml` are part of the active app-of-apps model.

## Prerequisites / Tooling

Most operations in this repo assume:

- A working kubeconfig for the `gerador` cluster
- A working Talos config for the same cluster
- These CLIs installed locally:
  - `helm`
  - `kubectl`
  - `talosctl`
  - `kubeseal`
  - `yq`

Unless noted otherwise, commands below are run from the repository root.

## Common Operations

### Create a Sealed Secret

This repo uses Sealed Secrets with controller name `sealed-secrets-controller` in namespace `sealed-secrets`.

Start with a normal Kubernetes `Secret` manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: default
type: Opaque
stringData:
  username: admin
  password: p4ssw0rd
```

Seal the manifest:

```shell
kubeseal --controller-namespace sealed-secrets -o yaml < secret.yaml > sealed-secret.yaml
```

To seal a single raw value:

```shell
echo -n '<VALUE>' | kubeseal --controller-namespace sealed-secrets --raw --namespace <NAMESPACE> --name <NAME>
```

### Restore the Sealed Secrets key in a new cluster

Only the controller key secret needs to be restored. In this repo that secret is named `sealed-secrets-key`.

Export the key from the source cluster:

```shell
kubectl get secret sealed-secrets-key -n sealed-secrets -o yaml \
  | yq 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.managedFields)' \
  > sealed-secrets-key.yaml
```

Apply it to the new cluster and restart the controller:

```shell
kubectl apply -f sealed-secrets-key.yaml
kubectl rollout restart -n sealed-secrets deployment sealed-secrets-controller
rm sealed-secrets-key.yaml
```

### Remove old ReplicaSets

List ReplicaSets with `spec.replicas == 0` and delete them:

```shell
kubectl get replicaset -A -o jsonpath='{range .items[?(@.spec.replicas==0)]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
  | while read -r namespace name; do
      [ -n "$namespace" ] && kubectl delete replicaset -n "$namespace" "$name"
    done
```

### Talos operations

The helper scripts in `talos/` use relative paths such as `./rendered/` and `./secrets.yaml`, so run them from inside the `talos/` directory.

The scripts also inspect live cluster state with `kubectl`, so they expect the node to exist in the cluster unless the command is specifically part of first-node bootstrap.

#### Update Talos config for one node

```shell
cd talos
sh ./update-config.sh -n korris-0
```

Dry-run without applying:

```shell
cd talos
sh ./update-config.sh -n korris-0 -d true
```

This regenerates the local machine config and, unless `-d true` is set, applies it with `talosctl apply`.

#### Update Talos config for all nodes

```shell
cd talos
sh ./update-all-config.sh -s 60
```

Dry-run all nodes:

```shell
cd talos
sh ./update-all-config.sh -d true -s 60
```

This walks every Kubernetes node returned by `kubectl get nodes`, regenerates its config, applies it, and waits `-s` seconds between nodes. The default wait is 60 seconds.

#### Create a new Talos node config

For a permanent node definition, add `talos/nodes/<node>.yaml`. In practice you will usually also add `talos/nodes/<node>-patch.yaml`, because the regular update workflow uses that patch file for host- and network-specific settings.

Then generate and optionally apply the initial config:

```shell
cd talos
sh ./create-node.sh -n new-node-0 -t worker -i 192.168.4.50
```

Dry-run without applying:

```shell
cd talos
sh ./create-node.sh -n new-node-0 -t worker -i 192.168.4.50 -d true
```

Supported node types are `worker` and `controlplane`.

`create-node.sh` generates the initial machine config and applies it with `talosctl apply-config --insecure` unless dry-run is enabled.

After the node has joined the cluster, run `update-config.sh -n <node>` to regenerate it with the fuller patch set used by the normal day-2 workflow.

#### Upgrade Talos on a node

```shell
cd talos
sh ./update-talos.sh -n korris-0 -v 1.12.5
```

This resolves the node schematic and internal IP from the live cluster, then runs `talosctl upgrade --preserve --wait`.

## Cluster / Hardware Snapshot

- Cluster name: `gerador`
- Control plane endpoint: `https://gerador.feddema.dev:6443`
- Talos node definitions live in `talos/nodes/`
- Current node inventory: 3 control-plane nodes and 6 workers
