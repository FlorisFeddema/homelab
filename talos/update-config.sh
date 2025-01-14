#!/bin/sh

while getopts n:c:d: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        n) nodeName=${OPTARG};;
        c) talosConfig=${OPTARG};;
        d) dryRun=${OPTARG};;
    esac
done

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi

if [ -z "$talosConfig" ]; then
  echo "talosConfig is empty"
  exit 1
fi

nodeType="worker"
controlPlane=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.labels | contains({"node-role.kubernetes.io/control-plane": ""})')
if [ "$controlPlane" = "true" ]; then
  nodeType="controlplane"
fi
echo "⚙️ Node is a $nodeType"

clusterName="gerador"
kubernetesVersion=$(kubectl version -o yaml | yq '.serverVersion.gitVersion' | tr -d v)
nodeIP=$(kubectl get node "$nodeName" -o yaml | yq '.status.addresses[] | select(.type == "InternalIP") | .address')
configFile=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.labels["feddema.dev/talos-configfile"]')

echo "⚙️ Generating Talos config for $nodeName"
talosctl gen config $clusterName https://"$nodeIP":6443 \
    --output ./rendered/"$configFile".yaml \
    --output-types "$nodeType"                       \
    --with-cluster-discovery=false                    \
    --with-secrets ./secrets.yaml                       \
    --config-patch @"$configFile".yaml   \
    --config-patch @cluster.yaml                      \
    --kubernetes-version "$kubernetesVersion"    \
    --force

if [ -z "$dryRun" ]; then
  echo "⚙️ Applying Talos config for $nodeName"
  talosctl apply-config --nodes $nodeIP --file ./rendered/"$configFile".yaml
else
  echo "⚙️ Running in dry-run mode, skipping apply-config"
fi
