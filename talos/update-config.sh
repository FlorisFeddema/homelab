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
echo "⚙️ Node is a $nodeType"

clusterName="gerador"
clusterDomain="https://gerador.feddema.dev:6443"
kubernetesVersion=$(kubectl version -o yaml | yq '.serverVersion.gitVersion' | tr -d v)
nodeIP=$(kubectl get node "$nodeName" -o yaml | yq '.status.addresses[] | select(.type == "InternalIP") | .address')
configFile=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.labels["feddema.dev/talos-configfile"]')

echo "⚙️ Generating Talos config for $nodeName"
talosctl gen config $clusterName $clusterDomain \
    --output ./rendered/"$configFile".yaml \
    --output-types "$nodeType"                       \
    --with-cluster-discovery=false                    \
    --with-secrets ./secrets.yaml                       \
    --config-patch @"nodes/$configFile".yaml   \
    --config-patch @"$nodeType".yaml   \
    --config-patch @cluster.yaml                      \
    --kubernetes-version "$kubernetesVersion"    \
    --force

if [ -z "$dryRun" ]; then
  echo "⚙️ Applying Talos config for $nodeName"
  talosctl apply-config --nodes "$nodeIP" --file ./rendered/"$configFile".yaml
else
  echo "⚙️ Running in dry-run mode, skipping apply-config"
fi
