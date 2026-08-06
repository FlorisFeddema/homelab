---
description: "Guidance for creating and updating Helm product charts in this homelab"
applyTo: "chart/**/*.yaml, chart/**/*.yml, products/**/*.yaml, products/**/*.yml, products/**/*.tpl"
---

# Helm Chart Management

These rules apply to the top-level Argo CD chart and product charts under `products/`.

## Repository Model

- `chart/values.yaml` is the authoritative inventory of deployed products.
- A chart under `products/` is not live unless it is registered and enabled in `chart/values.yaml`.
- The top-level `chart/` renders Argo CD `Application` objects.
- Each product lives in one chart at `products/<group>/<product>/`.
- Keep product charts concrete and environment-specific.
- Put reusable logic in `templates/` or shared chart helpers instead of copying it between products.

## Creating A Product Chart

1. Choose an existing group under `products/` and create a kebab-case product directory.
2. Copy the closest existing chart in the same group. Use `products/_base/` only when no comparable chart exists.
3. Create the chart foundation:
   - `Chart.yaml` with `apiVersion: v2`, chart name, version, and required dependencies.
   - `values.yaml` with concrete values and safe defaults.
   - Templates for only the namespace, workload, service, route, storage, monitoring, and secrets the product owns.
4. Decide namespace ownership:
   - Add `templates/namespace.yaml` for a dedicated namespace owned by the chart.
   - Omit it when sharing an existing namespace.
   - Set `namespace` in `chart/values.yaml` when the Argo CD destination namespace differs from the product name.
5. Inspect upstream application configuration for required ports, health endpoints, persistence, and environment variables.
6. Put non-secret configuration in values or a ConfigMap.
7. Create secrets that users do not need to provide with an idempotent init-secret Job.
8. Require user-provided credentials through Sealed Secrets; never commit plaintext credentials.
9. Reuse CNPG-generated Secrets for database credentials where available.

## Platform Integrations

- Use existing HTTPRoute and Authentik OIDC patterns for web applications.
- Define PVCs and Velero backup annotations for local state.
- Use Rook Ceph object-storage patterns for S3-compatible data.
- Add PodMonitor, ServiceMonitor, Gatus, or dashboards when useful observability is available.
- Make optional backups and storage integrations conditional in templates.
- Decide whether state uses a PVC, S3/RGW, or both before enabling the product.
- If a database is required, use the existing CNPG patterns and make generated or externally provisioned credentials explicit.

## Registering A Product

Add the product to `chart/values.yaml`:

```yaml
products:
  <group>:
    <productKey>:
      deploy: false
      autoSync: false
```

Set `deploy: true` only when the chart is ready. Set `autoSync`, `namespace`, `nameOverride`, `serverSideApply`, or diff options only when required.

## Validation

Run these commands before enabling deployment:

```shell
helm lint products/<group>/<product>
helm template <product> products/<group>/<product> --namespace <namespace>
helm template homelab chart/
```

Inspect rendered namespaces, routes, secret references, storage classes, probes, and Argo CD Application paths. Keep product-specific resources in the product chart; cluster-wide infrastructure and reusable logic belong in their existing platform chart or shared templates.
