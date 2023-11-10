# Welcome to Our Kubernetes Configuration Repository HomeLab

## Overview

This repository contains all the configuration files and resources for our Kubernetes cluster using Talos Kubernetes OS. We've integrated tools like ArgoCD and Kubeseal to manage and secure our configurations effectively.

## Cluster Details

- **Operating System**: Talos Kubernetes OS
- **Apps**: See /apps
- **Tools Used**:
  - talosctl
  - crane (google)
  - kubectl
  - kubeseal
  - 

### Create talos boot and update images with required drivers

Talos is an immutable OS so we can't install additional packages after boot. However not all required system packages are available by default.
Talos allows creating customized OS images using their [imager container](https://www.talos.dev/v1.5/talos-guides/install/boot-assets/)

We currently use the following talos-provided additional components:
- https://github.com/siderolabs/extensions/tree/main/storage/iscsi-tools
- https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent

Talos system-extensions are compatible with specific versions of talos. To find the correct extension version for the talos version run:

```
TALOS_CONFIG=/path/to/talos/config
TALOS_VERSION=$(talosctl version --short | grep Tag | sed -n 's/.*Tag://p' | sed -e 's/^[ \t]*//')
echo $TALOS_VERSION
```

Then run:

```
crane export ghcr.io/siderolabs/extensions:$TALOS_VERSION | tar x -O image-digests | grep <extension-name>
```

Example:

```
ISCSI_IMAGE=$(crane export ghcr.io/siderolabs/extensions:$TALOS_VERSION | tar x -O image-digests | grep iscsi-tools)
QEMU_IMAGE=$(crane export ghcr.io/siderolabs/extensions:$TALOS_VERSION | tar x -O image-digests | grep qemu)
echo $ISCSI_IMAGE
echo $QEMU_IMAGE
```

To create the custom image run the `imager` container with the following command:

```
mkdir _images
docker run --rm -t -v $PWD/_images:/out --privileged ghcr.io/siderolabs/imager:$TALOS_VERSION iso \
  --system-extension-image $ISCSI_IMAGE --system-extension-image $QEMU_IMAGE
docker run --rm -t -v $PWD/_images:/out --privileged ghcr.io/siderolabs/imager:$TALOS_VERSION installer \
  --system-extension-image $ISCSI_IMAGE --system-extension-image $QEMU_IMAGE
```

Now upload the installer iso and image to proxmox and the container registry. Go to https://github.com/settings/tokens/new?scopes=write:packages and create a new PAT with the selected scope.

```
GHCR_TOKEN=""
echo $GHCR_TOKEN | docker login ghcr.io -u TOKEN --password-stdin
crane push _images/metal-amd64-installer.tar ghcr.io/broersma-forslund/homelab/talos-installer:$TALOS_VERSION
```

### Create talos nodes

Boot machine with custom talos ISO and perform the below steps

Control plane nodes:

```
TALOS_CONFIG=/path/to/talos/config
CONTROL_PLANE=0
talosctl gen config talos-broersma https://10.0.10.111:6443             \
    --output rendered/control-plane-$CONTROL_PLANE.yaml                 \
    --output-types controlplane                                         \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/cluster-endpoint.yaml                 \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/nodes/control-plane-$CONTROL_PLANE.yaml       \
    --config-patch @talos/nodes/control-plane-all.yaml
```

`talosctl apply-config --nodes <node-x-ip> --file rendered/control-plane-$CONTROL_PLANE.yaml`

```
TALOS_CONFIG=/path/to/talos/config
WORKER=0
talosctl gen config talos-broersma https://10.0.10.111:6443             \
    --output rendered/worker-$WORKER.yaml                               \
    --output-types worker                                               \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/cluster-endpoint.yaml                 \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/nodes/worker-$WORKER.yaml
```

`talosctl apply-config --nodes <node-x-ip> --file rendered/worker-$WORKER.yaml`

### Upgrading talos

To update talos use our custom intaller image containing the required system extensions

```
TALOS_CONFIG=/path/to/talos/config
TALOS_UPGRADE_VERSION=""
talosctl upgrade --nodes <node-x-ip> --image ghcr.io/broersma-forslund/homelab/talos-installer:$TALOS_UPGRADE_VERSION --preserve
```
