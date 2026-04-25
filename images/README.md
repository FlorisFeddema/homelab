# Images

This directory contains Docker build definitions for images used by Argo Workflows and other homelab workloads.

## Layout

Each directory under `images/` that contains both a `Dockerfile` and a `version` file is treated as a standalone image build when the GitHub Actions workflow runs.
Each image directory must contain a `version` file with a semantic version such as `1.0.0`.

Minimum structure:

```text
images/
  <image-name>/
    Dockerfile
    version
  <group>/
    <image-name>/
      Dockerfile
      version
```

The pushed Harbor image name is:

```text
<HARBOR_REGISTRY>/<HARBOR_PROJECT>/<path-under-images>
```

Published tags include:

- `<major>.<minor>.<patch>`
- `<major>.<minor>`
- `<major>` when the major version is not `0`
- `sha-<commit>`
- `latest` from the default branch

The workflow fails before building if the exact `<major>.<minor>.<patch>` tag already exists in Harbor.

For `workflow_dispatch` runs:

- `image` can limit the run to a single image path such as `argo-workflows/go`
- `push=false` performs a build-only validation run
- `push=true` publishes to Harbor
- `force_push=true` bypasses the duplicate-version check for manual emergency rebuilds

## GitHub Actions Configuration

The image workflow expects these repository secrets:

- Repository secret `HARBOR_USERNAME`
- Repository secret `HARBOR_PASSWORD`

The registry and project are currently defined directly in the workflow:

- `HARBOR_REGISTRY=harbor.feddema.dev`
- `HARBOR_PROJECT=argo-workflows`
