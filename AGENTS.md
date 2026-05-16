# Homelab Repo Guide

## Goal

This repo manages `gerador`, a Talos-based Kubernetes homelab.

Primary model:
- Talos defines cluster and node machine config.
- Argo CD deploys workloads GitOps-style.
- `chart/` renders Argo CD `Application` objects.
- `products/` contains per-product Helm charts.

`chart/values.yaml` is source of truth for what is actually deployed. A chart under `products/` is not live unless enabled there.

## Folder Structure

- `chart/`
  Top-level Helm chart that renders Argo CD applications.
- `chart/values.yaml`
  Product inventory, deploy flags, namespaces, sync options, and Argo CD diff/apply settings.
- `products/<group>/<product>/`
  Per-product Helm charts synced by Argo CD.
- `products/_base/`
  Base scaffolding for new product charts.
- `templates/`
  Shared Helm dependencies and reusable templates.
- `talos/`
  Cluster-wide Talos config, node definitions, patches, and helper scripts.
- `talos/nodes/`
  Per-node machine config and patch files.
- `unifi/`
  Network-related config outside Kubernetes manifests.
- `images/`
  Build context for Argo Workflows images built by GitHub Actions.

## Important Tools And Systems

Core platform:
- Kubernetes
- Talos
- Argo CD
- Helm
- Cilium
- CoreDNS

Security and secrets:
- Sealed Secrets
- `kubeseal`
- Authentik
- cert-manager

Storage and backup:
- Rook Ceph
- CloudNativePG
- Velero

Observability:
- Prometheus
- Grafana
- Loki
- Gatus

Network and edge:
- Unifi
- external-dns
- Envoy Gateway
- AdGuard

Useful CLIs:
- `kubectl`
- `talosctl`
- `helm`
- `kubeseal`
- `yq`

## Operating Conventions

- Treat `chart/values.yaml` as authoritative inventory.
- Keep product charts environment-specific and concrete.
- Prefer one chart per product under `products/<group>/<product>/`.
- Put shared logic in `templates/` or reusable chart helpers, not copy-pasted everywhere.
- Secrets should not be committed in plaintext. Use Sealed Secrets or existing secret patterns already used by neighboring charts.
- Follow existing naming and namespace patterns from similar products in same group.
- When possible, copy patterns from nearest comparable chart instead of inventing new structure.

## Add New Product / Helm Chart

First iteration. Refine later.

1. Choose correct group under `products/`.
2. Start from `products/_base/` or copy closest existing product in same category.
3. Create minimal chart files:
   - `Chart.yaml`
   - `values.yaml`
   - `templates/namespace.yaml` when chart owns namespace
   - workload/service/route/secret templates as needed
4. Reuse existing patterns for:
   - namespace ownership
   - OIDC/Auth via Authentik
   - sealed secrets
   - security policy manifests
   - backup annotations
   - storage classes and PVCs
   - Grafana dashboards or monitors when product needs observability
5. Add product entry to `chart/values.yaml`.
6. Set deploy flags, namespace, and any Argo CD sync options there.
7. Check whether product should share namespace with existing stack or get dedicated namespace.
8. Keep chart focused. Shared infra belongs in separate product or shared template, not embedded ad hoc.

Heuristics:
- If similar app already exists, mirror its structure first.
- If app exposes UI/API, inspect existing route and auth patterns before adding ingress.
- If app stores state, define backup and storage story before enabling deploy.
- If app needs secrets, use existing sealed secret conventions from same area of repo.

## External Dependencies

Known external dependencies:
- Cloudflare DNS hosting
- Unifi network environment
- Authentik identity provider
- 1Password or another external secret source may be involved; confirm exact workflow before relying on it
- Azure-backed database/object storage appears in some charts; treat as product-specific dependency unless standardized

Likely cluster-level dependencies:
- Domain and TLS management
- S3-compatible backup/object storage for some workloads
- External MQTT / IoT integrations for home stack

## Good Subjects To Add Later

- Exact product creation checklist
- Secret management workflow, including 1Password if standard
- Validation commands before merge
- Namespace and naming conventions
- Storage class selection rules
- Ingress, DNS, and certificate patterns
- Talos change workflow and safety rules
