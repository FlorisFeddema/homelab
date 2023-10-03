#!/bin/bash

app=$1
namespace=$2

if [ -z "$app" ]; then
    echo "no app given"
    exit 1
fi

if [ -z "$namespace" ]; then
    namespace=$app
fi

basePath=products/$app

helm dependency build $basePath

command="helm upgrade --install $app $basePath --namespace $namespace

echo "*********************"
echo $command
echo "*********************"

eval $command
