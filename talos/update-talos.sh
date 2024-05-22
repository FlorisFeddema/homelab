#!/bin/sh

while getopts n:v:f:c: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        n) nodeName=${OPTARG};;
        v) talosVersion=${OPTARG};;
        f) forcePush=${OPTARG};;
        c) talosConfig=${OPTARG};;
    esac
done

rke="kashaylan"

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi

if [ -z "$talosVersion" ]; then
  echo "talosVersion is empty"
  exit 1
fi

if [ -z "$talosConfig" ]; then
  echo "talosConfig is empty"
  exit 1
fi

nodeIP=$(kubectl get node "$nodeName" -o yaml | yq '.status.addresses[] | select(.type == "InternalIP") | .address')

nodeType="worker"
controlPlane=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.labels | contains({"node-role.kubernetes.io/control-plane": ""})')
if [ "$controlPlane" = "true" ]; then
  nodeType="controlplane"
fi
echo "⚙️ Node is a $nodeType"

docker manifest inspect ghcr.io/florisfeddema/homelab/talos-installer:$talosVersion > /dev/null 2>&1
if [ $? -ne 0 ] || [ -n "$forcePush" ]; then
  echo "⚙️ Creating image for RKE module"
  iscsiImage=$(crane export ghcr.io/siderolabs/extensions:$talosVersion | tar x -O image-digests | grep iscsi-tools)
  utilImage=$(crane export ghcr.io/siderolabs/extensions:$talosVersion | tar x -O image-digests | grep util-linux-tools)
  rk3388Image=$(crane export ghcr.io/nberlee/extensions:$talosVersion | tar x -O image-digests | grep rk3588)
  echo "⚙️ iscsi image: $iscsiImage"
  echo "⚙️ util image: $utilImage"
  echo "⚙️ rk3388 image: $rk3388Image"
  mkdir _images
  docker run --rm -t -v ./_images:/out --privileged ghcr.io/nberlee/imager:"$talosVersion" iso --base-installer-image ghcr.io/nberlee/installer:"$talosVersion"-rk3588 --system-extension-image $iscsiImage --system-extension-image $utilImage --system-extension-image $rk3388Image
  docker run --rm -t -v ./_images:/out --privileged ghcr.io/nberlee/imager:"$talosVersion" installer --base-installer-image ghcr.io/nberlee/installer:"$talosVersion"-rk3588 --system-extension-image $iscsiImage --system-extension-image $utilImage --system-extension-image $rk3388Image
  echo "⚙️ pushing custom image ghcr.io/florisfeddema/homelab/talos-installer:$talosVersion"
  crane push ./_images/installer-arm64.tar ghcr.io/florisfeddema/homelab/talos-installer:$talosVersion
  rm -rf _images
else
  echo "⚙️ Image already exists, skipping build"
fi

# shellcheck disable=SC2039
if [[ $nodeName =~ $rke ]]; then
  echo "⚙️ Node is a RKE node, using custom image"
  installerImage="ghcr.io/florisfeddema/homelab/talos-installer:$talosVersion"
else
  echo "⚙️ Node is a normal node"
  # shellcheck disable=SC2162
  read -p "⚙️ Give x86 image with iscsi and linux utils extension from factory: (https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fiscsi-tools&extensions=siderolabs%2Futil-linux-tools&platform=metal&target=metal&version=$(echo $talosVersion | tr -d v))" installerImage
fi

echo "⚙️ Using image: $installerImage"

echo "⚙️ Updating Talos to version $talosVersion on node $nodeName"
talosctl upgrade --talosconfig $talosConfig --nodes $nodeIP --image $installerImage --preserve --wait

echo "⚙️ Upgraded node $nodeName to version $talosVersion successfully"
