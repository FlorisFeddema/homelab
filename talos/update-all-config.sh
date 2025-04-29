#!/bin/sh

while getopts d: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        d) dryRun=${OPTARG};;
    esac
done

for file in nodes/*.yaml; do
  nodeName=$(basename "$file" .yaml)
  echo "Processing $nodeName"
  sh ./update-config.sh -n "$nodeName" -d "$dryRun"
  if [ $? -ne 0 ]; then
    echo "Error processing $nodeName"
    exit 1
  fi
  echo "Sleeping for 60 seconds before processing the next node"
  sleep 60
done
