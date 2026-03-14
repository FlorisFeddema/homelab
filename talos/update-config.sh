#!/bin/sh

while getopts n:d: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        n) nodeName=${OPTARG};;
        d) dryRun=${OPTARG};;
    esac
done

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi

nodeType="worker"
controlPlane=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.labels | contains({"node-role.kubernetes.io/control-plane": ""})')
if [ "$controlPlane" = "true" ]; then
  nodeType="controlplane"
fi
echo "♟️️ Node is a $nodeType"

clusterName="gerador"
clusterDomain="https://$clusterName.feddema.dev:6443"
kubernetesVersion=$(kubectl version -o yaml | yq '.serverVersion.gitVersion' | tr -d v)

echo "⚙️ Generating Talos config for $nodeName"
talosctl gen config $clusterName $clusterDomain \
    --output ./rendered/"$nodeName".yaml \
    --output-types "$nodeType"                       \
    --with-cluster-discovery=false                    \
    --with-secrets ./secrets.yaml                       \
    --with-docs=false                      \
    --with-examples=false                      \
    --config-patch @nodes/"$nodeName".yaml   \
    --config-patch @"$nodeType".yaml   \
    --config-patch @cluster.yaml                      \
    --config-patch-control-plane @controlplane.yaml                      \
    --config-patch-worker @worker.yaml                      \
    --config-patch @cluster-patch.yaml \
    --config-patch @secret-patch.yaml \
    --config-patch @nodes/"$nodeName-patch".yaml \
    --kubernetes-version "$kubernetesVersion"    \
    --force

if [ -z "$dryRun" ]; then
  echo "🏗️️ Applying Talos config for $nodeName"
  talosctl apply --nodes "$nodeName" --file ./rendered/"$nodeName".yaml
else
  echo "🏗️️ Running in dry-run mode, skipping apply-config"
fi
