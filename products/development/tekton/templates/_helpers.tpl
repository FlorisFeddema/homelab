{{/* Workload names mapped to namespaces and pod selector labels. */}}
{{- define "tekton.workloads" -}}
{{- $workloads := dict -}}
{{- range $component := list "operator" "webhook" -}}
{{- $name := ternary "tekton-operator" "tekton-operator-webhook" (eq $component "operator") -}}
{{- $_ := set $workloads $name (dict
  "namespace" $.Release.Namespace
  "selectorLabels" (dict
    "app.kubernetes.io/component" $component
    "app.kubernetes.io/instance" $.Release.Name
    "app.kubernetes.io/name" "tekton-operator"
  )
) -}}
{{- end -}}
{{- $components := dict
  "tekton-dashboard" (dict
    "tekton-dashboard" "dashboard"
  )
  "tekton-pipelines" (dict
    "tekton-events-controller" "events"
    "tekton-pipelines-controller" "controller"
    "tekton-pipelines-remote-resolvers" "resolvers"
    "tekton-pipelines-webhook" "webhook"
  )
  "tekton-triggers" (dict
    "tekton-triggers-controller" "controller"
    "tekton-triggers-core-interceptors" "core-interceptors"
    "tekton-triggers-webhook" "webhook"
  )
-}}
{{- range $partOf, $deployments := $components -}}
{{- range $deployment, $name := $deployments -}}
{{- $_ := set $workloads $deployment (dict
  "namespace" "tekton-operator"
  "selectorLabels" (dict
    "app.kubernetes.io/instance" "default"
    "app.kubernetes.io/name" $name
    "app.kubernetes.io/part-of" $partOf
  )
) -}}
{{- end -}}
{{- end -}}
{{- $_ := set $workloads "tekton-operator-proxy-webhook" (dict
  "namespace" "tekton-operator"
  "selectorLabels" (dict "name" "tekton-operator-proxy-webhook")
) -}}
{{- toYaml $workloads -}}
{{- end -}}
