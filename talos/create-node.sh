#!/bin/sh

while getopts n:d:t:i: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        n) nodeName=${OPTARG};;
        d) dryRun=${OPTARG};;
        t) nodeType=${OPTARG};;
        i) nodeIP=${OPTARG};;
    esac
done

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi

if [ -z "$nodeType" ]; then
  echo "$nodeType is empty"
  exit 1
fi

if [ -z "$nodeIP" ]; then
  echo "nodeIP is empty"
  exit 1
fi

if [ "$nodeType" != "worker" ] && [ "$nodeType" != "controlplane" ]; then
  echo "nodeType must be either worker or controlplane"
  exit 1
fi

clusterName="gerador"
clusterDomain="https://gerador.feddema.dev:6443"
kubernetesVersion=$(kubectl version -o yaml | yq '.serverVersion.gitVersion' | tr -d v)

echo "⚙️ Generating Talos config for $nodeName"
talosctl gen config $clusterName $clusterDomain \
    --output ./rendered/"$nodeName".yaml \
    --output-types "$nodeType"                       \
    --with-cluster-discovery=false                    \
    --with-secrets ./secrets.yaml                       \
    --config-patch @"nodes/$nodeName".yaml   \
    --config-patch @"$nodeType".yaml   \
    --config-patch @cluster.yaml                      \
    --kubernetes-version "$kubernetesVersion"    \
    --force

if [ -z "$dryRun" ]; then
  echo "⚙️ Applying Talos config for $nodeName"
  talosctl apply-config --nodes "$nodeIP" --file ./rendered/"$nodeName".yaml --insecure
else
  echo "⚙️ Running in dry-run mode, skipping apply-config"
fi
