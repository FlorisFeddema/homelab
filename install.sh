#!/bin/bash

basePath=$1

if [ -z "$basePath" ]; then
    echo "no path"
fi

applicationPath=$basePath/application.yaml
valuesPath=$basePath/values.yaml
namespacePath=$basePath/namespace.yaml
files=$(find $basePath -type f | grep ".yaml" | grep -v "application.yaml" | grep -v "values.yaml" | grep -v "namespace.yaml")

namespace=$(yq '.spec.destination.namespace' $applicationPath )
chart=$(yq '.spec.source.chart' $applicationPath )
repo=$(yq '.spec.source.repoURL' $applicationPath )
version=$(yq '.spec.source.targetRevision' $applicationPath )
name=$(yq '.metadata.name' $applicationPath )

yq '.spec.source.helm.values' $applicationPath > $valuesPath

helm repo add temp $repo
helm repo update

kubectl apply -f $namespacePath

echo "$files" | while read line ; do
   kubectl apply -f $line
done

command="helm upgrade --install $name temp/$chart --namespace $namespace --values $valuesPath --version $version"

echo "*********************"
echo $command
echo "*********************"

eval $command

helm repo remove temp

