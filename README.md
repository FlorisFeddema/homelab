# Welcome to Our Kubernetes Configuration Repository HomeLab

## Overview

This repository contains all the configuration files and resources for our Kubernetes cluster using Talos Kubernetes OS. We've integrated tools like ArgoCD and Kubeseal to manage and secure our configurations effectively.

## Cluster Details

- **Operating System**: Talos Kubernetes OS
- **Tools Used**:
  - **ArgoCD**: For continuous deployment and management of Kubernetes resources.
  - **Kubeseal**: For managing and encrypting Kubernetes secrets.

## Structure

The repository is organized as follows:

- `/argocd`: Contains configuration files for ArgoCD.
- `/kubeseal`: Stores encrypted secrets using Kubeseal.
- `/manifests`: Kubernetes manifests and configurations for various applications and services.
- `/scripts`: Handy scripts for managing or automating certain processes.

## Setup Instructions

### Prerequisites

- A running Kubernetes cluster provisioned with Talos Kubernetes OS.
- ArgoCD and Kubeseal installed and configured within the cluster.
- kubectl CLI configured to interact with the cluster.


### talos
Control plane nodes:

```
talosctl gen config                                                     \
    --output rendered/control-plane-0.yaml                              \
    --output-types controlplane                                         \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/nodes/control-plane-0.yaml                    \
    --config-patch @talos/nodes/control-plane-all.yaml                  \
    $CLUSTER_NAME                                                       \
    $CONTROL_PLANE_0 --force
```

`talosctl apply-config --insecure --nodes $CONTROL_PLANE_0 --file rendered/control-plane-0.yaml`

``` 
talosctl gen config                                                     \
    --output rendered/worker/0.yaml                                     \
    --output-types worker                                               \
    --with-cluster-discovery=false                                      \
    --with-secrets secrets.yaml                                         \
    --config-patch @talos/patches/cluster-name.yaml                     \
    --config-patch @talos/patches/disable-cni-and-kube-proxy.yaml       \
    --config-patch @talos/nodes/worker-0.yaml                           \  
    --config-patch @talos/nodes/worker-all.yaml                         \
    $CLUSTER_NAME                                                       \
    $CONTROL_PLANE_0 --force
```

`talosctl apply-config --insecure --nodes $WORKER_0 --file rendered/worker-0.yaml`
