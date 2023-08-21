#!/bin/bash

path=$1
app=$2

basePath=$path/$app

if [ -z "$basePath" ]; then
    echo "no path"
    exit 1
fi

applicationFile=$path/$app.yaml
valuesFile=$basePath/values.yaml
namespaceFile=$basePath/namespace.yaml
files=$(find $basePath -type f | grep ".yaml" | grep -v "application.yaml" | grep -v "values.yaml" | grep -v "namespace.yaml")

namespace=$(yq '.spec.destination.namespace' $applicationFile )
chart=$(yq '.spec.sources[1].chart' $applicationFile )
repo=$(yq '.spec.sources[1].repoURL' $applicationFile )
version=$(yq '.spec.sources[1].targetRevision' $applicationFile )
name=$(yq '.metadata.name' $applicationFile )

helm repo add temp $repo
helm repo update

kubectl apply -f $namespaceFile

echo "$files" | while read line ; do
   kubectl apply -f $line
done

if [[ "$repo" == *"https://"* ]]; then
    command="helm upgrade --install $name temp/$chart --namespace $namespace --values $valuesFile --version $version"
else
    command="helm upgrade --install $name oci://$repo/$chart --namespace $namespace --values $valuesFile --version $version"
fi

echo "*********************"
echo $command
echo "*********************"

eval $command

helm repo remove temp

