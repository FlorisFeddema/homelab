# Welcome to Our Kubernetes Configuration Repository HomeLab

## Overview

This repository contains all the configuration files and resources for our Kubernetes cluster using Talos Kubernetes OS. We've integrated tools like ArgoCD and Kubeseal to manage and secure our configurations effectively.

## Cluster Details

- **Operating System**: Talos Kubernetes OS
- **Apps**: See /apps
- **Tools Used**:
  - talosctl
  - kubectl
  - kubeseal

### Create talos nodes

Boot machine with custom talos ISO and perform the below steps

Control plane nodes:

```
export TALOSCONFIG=/path/to/talos/config
CONTROLPLANE=0
NODEIP=10.0.10.111
talosctl gen config talos-broersma https://$NODEIP:6443             \
    --output rendered/control-plane-$CONTROLPLANE.yaml                 \
    --output-types controlplane                                         \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/cluster-endpoint.yaml                 \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/patches/enable-kubeprism.yaml                 \
    --config-patch @talos/nodes/control-plane-$CONTROLPLANE.yaml       \
    --config-patch @talos/nodes/control-plane-all.yaml
```

`talosctl apply-config --nodes $NODEIP --file rendered/control-plane-$CONTROLPLANE.yaml`

```
export TALOSCONFIG=/path/to/talos/config
WORKER=0
NODEIP=10.0.10.12
talosctl gen config talos-broersma https://$NODEIP:6443             \
    --output rendered/worker-$WORKER.yaml                               \
    --output-types worker                                               \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/cluster-endpoint.yaml                 \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/patches/enable-kubeprism.yaml                 \
    --config-patch @talos/nodes/worker-$WORKER.yaml
```

`talosctl apply-config --nodes $NODEIP --file rendered/worker-$WORKER.yaml`

### Upgrading talos

To update talos create a custom image with the [talos image factory](https://factory.talos.dev/).

Select per host the required talos packages. You must also update new nodes immediately to install required packages.

```
export TALOSCONFIG=/path/to/talos/config
NODEIP=10.0.10.12
TALOSIMAGE=factory.talos.dev/installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.6.4
talosctl upgrade --nodes $NODEIP --image $TALOSIMAGE
```
