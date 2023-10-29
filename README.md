# homelab

## talos
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
