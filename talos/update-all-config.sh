#!/bin/sh

while getopts d:s: flag
do
    # shellcheck disable=SC2220
    case "${flag}" in
        d) dryRun=${OPTARG};;
        s) seconds=${OPTARG};;
    esac
done

if [ -z "$seconds" ]; then
    seconds=60
fi

for file in nodes/*.yaml; do
  nodeName=$(basename "$file" .yaml)
  echo "Processing $nodeName"
  sh ./update-config.sh -n "$nodeName" -d "$dryRun"
  if [ $? -ne 0 ]; then
    echo "Error processing $nodeName"
    exit 1
  fi
  echo "Sleeping for $seconds seconds before processing the next node"
  sleep "$seconds"
done
