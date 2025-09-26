#!/bin/sh

while getopts n:v: flag
do
    case "${flag}" in
        n) nodeName=${OPTARG};;
        v) version=${OPTARG};;
    esac
done

if [ -z "$nodeName" ]; then
  echo "nodeName is empty"
  exit 1
fi
if [ -z "$version" ]; then
  echo "version is empty"
  exit 1
fi

schematic=$(kubectl get node "$nodeName" -o yaml | yq '.metadata.annotations."extensions.talos.dev/schematic"')
nodeIP=$(kubectl get node "$nodeName" -o yaml | yq '.status.addresses[] | select(.type == "InternalIP") | .address')

installerImage="factory.talos.dev/metal-installer/$schematic:v$version"

echo "⚙️ Updating Talos on node $nodeName"
talosctl upgrade --nodes "$nodeIP" --image "$installerImage" --preserve --wait

echo "⚙️ Upgraded node $nodeName successfully"
