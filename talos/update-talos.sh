#!/bin/sh

while getopts n:i: flag
do
    case "${flag}" in
        n) nodeName=${OPTARG};;
        i) installerImage=${OPTARG};;
    esac
done

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi

if [ -z "$installerImage" ]; then
  echo "installerImage is empty"
  exit 1
fi

nodeIP=$(kubectl get node "$nodeName" -o yaml | yq '.status.addresses[] | select(.type == "InternalIP") | .address')

echo "⚙️ Updating Talos on node $nodeName"
talosctl upgrade --nodes "$nodeIP" --image "$installerImage" --preserve --wait

echo "⚙️ Upgraded node $nodeName successfully"
