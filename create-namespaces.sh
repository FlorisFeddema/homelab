#!/bin/bash

files=$(find . -type f | grep "namespace.yaml")

echo "$files" | while read line ; do
   kubectl apply -f $line
done
