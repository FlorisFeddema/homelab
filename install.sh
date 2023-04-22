#!/bin/bash

basePath=$1

if [ -z "$basePath" ]; then
    echo "no path"
    exit 1
fi

applicationFile=$basePath/application.yaml
valuesFile=$basePath/values.yaml
namespaceFile=$basePath/namespace.yaml
applyFile=$basePath/apply.yaml
files=$(find $basePath -type f | grep ".yaml" | grep -v "application.yaml" | grep -v "values.yaml" | grep -v "namespace.yaml")

namespace=$(yq '.spec.destination.namespace' $applicationFile )
chart=$(yq '.spec.source.chart' $applicationFile )
repo=$(yq '.spec.source.repoURL' $applicationFile )
version=$(yq '.spec.source.targetRevision' $applicationFile )
name=$(yq '.metadata.name' $applicationFile )

yq '.spec.source.helm.values' $applicationFile > $valuesFile

helm repo add temp $repo
helm repo update

kubectl apply -f $namespaceFile

echo "$files" | while read line ; do
   kubectl apply -f $line
done

command="helm upgrade --install $name temp/$chart --namespace $namespace --values $valuesFile --version $version"

echo "*********************"
echo $command
echo "*********************"

eval $command

helm repo remove temp
rm $valuesFile

