# Homelab Repo Guide

## Goal

This repo manages `gerador`, a Talos-based Kubernetes homelab.

Primary model:
- Talos defines cluster and node machine config.
- Argo CD deploys workloads GitOps-style.
- `chart/` renders Argo CD `Application` objects.
- `products/` contains per-product Helm charts.

`chart/values.yaml` is source of truth for what is actually deployed. A chart under `products/` is not live unless enabled there.

Detailed Helm chart management guidance is scoped to chart files in `.github/instructions/helm-chart-management.instructions.md`.

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

## MCP Servers Available To Copilot

These MCP servers are deployed in-cluster and intended for Copilot agent usage:

- Argo CD MCP server
  - Route: `https://argocd.mcp.feddema.dev`
  - Mode: read-only (`MCP_READ_ONLY=true`)
- Grafana MCP server
  - Route: `https://grafana.mcp.feddema.dev`
  - Mode: write actions disabled (`--disable-write`)

Both servers are enabled in `chart/values.yaml` under `products.ai`.

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
