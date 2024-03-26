# Homelab

<!-- TOC -->
* [homelab](#homelab)
  * [Kubeseal](#kubeseal)
    * [Restore key in new cluster](#restore-key-in-new-cluster)
  * [Remove old replica sets](#remove-old-replica-sets)
  * [Known issues](#known-issues)
  * [Hardware setup](#hardware-setup)
  * [Talos](#talos)
    * [Generate secrets](#generate-secrets)
    * [Create nodes](#create-nodes)
      * [Control plane](#control-plane)
      * [Worker](#worker)
    * [Upgrade nodes](#upgrade-nodes)
<!-- TOC -->

## Kubeseal

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: default
type: Opaque
stringData:
  username: "admin"
  password: "p4ssw0rd"
```

To create a new encrypted secret run the following command:

```shell
kubeseal --controller-namespace sealed-secrets -o yaml <INPUT.yaml >OUTPUT.yaml
```

To encrypt a single value run the following command:

```shell
echo -n <VALUE> | kubeseal --controller-namespace sealed-secrets --raw --namespace <NAMESPACE> --name <NAME>
```

### Restore key in new cluster

```shell
kubectl get secrets -n sealed-secrets -o yaml > out.yaml
!! UPDATE KEY AND CRT !!
kubectl apply -f out.yaml
rm out.yaml
kubectl rollout restart -n sealed-secrets deployment sealed-secrets-controller
```

## Remove old replica sets

```shell
kubectl get replicaset -o jsonpath='{ .items[?(@.spec.replicas==0)]}' -A | k delete -f -
```

## Known issues

- https://longhorn.io/kb/troubleshooting-volume-with-multipath/

## Hardware setup

- [ ] Zandorya
  - [ ] RK1
  - [ ] RK1
  - [ ] RK1
  - [ ] RK1

## Talos

### Generate secrets

This only has to be run once for a cluster.

```shell
talosctl gen secrets
talosctl gen config $CLUSTERNAME https://$NODEIP:6443 \
    --output-types talosconfig                        \
    --with-cluster-discovery=false                    \
    --with-secrets secrets.yaml                       \
    --config-patch @controlplane-$CONTROLPLANE.yaml   \
    --config-patch @controlplane-all.yaml             \
    --config-patch @cluster.yaml
```

### Create nodes

#### Control plane

```shell
export TALOSCONFIG=./talosconfig
CLUSTERNAME=gerador
CONTROLPLANE=0
NODEIP=192.168.4.11
talosctl gen config $CLUSTERNAME https://$NODEIP:6443 \
    --output rendered/controlplane-$CONTROLPLANE.yaml \
    --output-types controlplane                       \
    --with-cluster-discovery=false                    \
    --with-secrets secrets.yaml                       \
    --config-patch @controlplane-$CONTROLPLANE.yaml   \
    --config-patch @controlplane-all.yaml             \
    --config-patch @cluster.yaml
    
talosctl apply-config --insecure --nodes $NODEIP --file rendered/controlplane-$CONTROLPLANE.yaml
```

#### Worker

```shell
export TALOSCONFIG=./talosconfig
CLUSTERNAME=gerador
WORKER=1
NODEIP=192.168.4.14
talosctl gen config $CLUSTERNAME https://$NODEIP:6443 \
    --output rendered/worker-$WORKER.yaml \
    --output-types worker                       \
    --with-cluster-discovery=false                    \
    --with-secrets secrets.yaml                       \
    --config-patch @worker-$WORKER.yaml   \
    --config-patch @worker-all.yaml             \
    --config-patch @cluster.yaml
    
talosctl apply-config --insecure --nodes $NODEIP --file rendered/worker-$WORKER.yaml
```

```shell
talosctl --nodes $NODEIP bootstrap
talosctl --nodes $NODEIP kubeconfig
talosctl --nodes $NODEIP dashboard
```

### Upgrade nodes

```shell
TALOSCONFIG=./talosconfig
TALOS_VERSION=v1.6.5
echo $TALOS_VERSION

ISCSI_IMAGE=$(crane export ghcr.io/siderolabs/extensions:$TALOS_VERSION | tar x -O image-digests | grep iscsi-tools)
UTIL_IMAGE=$(crane export ghcr.io/siderolabs/extensions:$TALOS_VERSION | tar x -O image-digests | grep util-linux-tools)
RK3588_IMAGE=$(crane export ghcr.io/nberlee/extensions:$TALOS_VERSION | tar x -O image-digests | grep rk3588)
echo $ISCSI_IMAGE
echo $UTIL_IMAGE
echo $RK3588_IMAGE
mkdir _images
docker run --rm -t -v $PWD/_images:/out --privileged ghcr.io/nberlee/imager:$TALOS_VERSION iso --system-extension-image $ISCSI_IMAGE --system-extension-image $UTIL_IMAGE --system-extension-image $RK3588_IMAGE
docker run --rm -t -v $PWD/_images:/out --privileged ghcr.io/nberlee/imager:$TALOS_VERSION installer --system-extension-image $ISCSI_IMAGE --system-extension-image $UTIL_IMAGE --system-extension-image $RK3588_IMAGE

crane push _images/installer-arm64.tar ghcr.io/florisfeddema/homelab/talos-installer:$TALOS_VERSION
```

```shell
TALOSCONFIG=./talosconfig
NODEIP=192.168.4.11
TALOS_IMAGE=ghcr.io/florisfeddema/homelab/talos-installer:$TALOS_VERSION
talosctl upgrade --nodes $NODEIP --image $TALOS_IMAGE --preserve
```

## UDM 

### BGP Setup

Note: see files in udm folder.

Install Unifi utilities to run on boot.

```shell
curl -fsL "https://raw.githubusercontent.com/unifi-utilities/unifios-utilities/HEAD/on-boot-script-2.x/remote_install.sh" | /bin/sh
```

Create run on boot script to install frr in `/data/on_boot.d/10-onboot-frr.sh`.

Enable BGP by setting `bgpd=yes` in `/etc/frr/daemons`.

Create BGP config in `/etc/frr/bgpd.conf`.

```shell

Chown BGP config to ffr user.

```shell
chown frr:frr /etc/frr/bgpd.conf
service frr restart
```

Check if it is working.

```shell
vtysh -c 'show ip bgp'
netstat -ar
```
