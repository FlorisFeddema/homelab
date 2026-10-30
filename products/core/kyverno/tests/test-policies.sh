#!/usr/bin/env bash
set -euo pipefail

for tool in helm yq jq kyverno; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Required test tool not found: %s\n' "$tool" >&2
    exit 1
  fi
done

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
patched_files=()
trap 'rm -f "$test_dir/policies.yaml" "$test_dir/policy.yaml" "$test_dir/cases.json" "$test_dir/resources.yaml" "$test_dir/kyverno-test.yaml" "${patched_files[@]}"; rmdir "$test_dir"' EXIT

helm template kyverno "$chart_dir" --namespace kyverno |
  yq -o=json -I=0 '.' |
  jq -s '
    if any(.[]; (.apiVersion // "" | startswith("kyverno.io/"))) then
      error("Deprecated Kyverno policy APIs must not be rendered")
    else . end |
    if [.[] | select(.kind == "DeletingPolicy" and .metadata.name == "clean-bare-pods") |
        .spec.schedule] != ["5 * * * *"] then
      error("Bare-Pod cleanup must run hourly at minute 5")
    else . end |
    if any(.[]; .metadata.name == "cleanup-empty-replicasets" or
                .metadata.name == "kyverno:cleanup-replicasets" or
                .metadata.name == "kyverno:cleanup-controller:additional") then
      error("Retired ReplicaSet cleanup policy and its original or temporary RBAC must not be rendered")
    else . end |
    if any(.[]; .kind == "ClusterRole" and .metadata.name == "kyverno:generate-vpa-policy" and
       any(.rules[]; .apiGroups == ["autoscaling.k8s.io"] and .resources == ["verticalpodautoscalers"] and
           (.verbs | index("watch")) != null)) | not then
      error("Native VPA synchronization requires watch permission")
    else . end |
    map(select(.apiVersion == "policies.kyverno.io/v1")) |
    if (map(.metadata.name) | sort) !=
       (["generate-vpa-for-workloads", "clean-bare-pods", "imagepullpolicy-always",
         "prevent-cpu-limits", "add-topology-spread-to-workloads", "set-revisionhistorylimit-zero",
         "prevent-default-namespace", "deny-ingress-resources", "require-pod-probes",
         "prevent-nodeport"] | sort) then
      error("All ten custom policies must use the stable CEL APIs")
    else . end |
    if any(.[]; .metadata.name == "generate-vpa-for-workloads" and
       (.spec.evaluation.generateExisting.enabled != true or .spec.evaluation.synchronize.enabled != true)) then
      error("VPA generation must retain existing-resource generation and synchronization")
    else . end |
    if (map(select(.spec.validationActions == ["Audit"]) | .metadata.name) | sort) !=
       ["prevent-cpu-limits", "prevent-nodeport", "require-pod-probes"] or
       (map(select(.spec.validationActions == ["Deny"]) | .metadata.name) | sort) !=
       ["deny-ingress-resources", "imagepullpolicy-always", "prevent-default-namespace"] then
      error("Validation enforcement modes must be preserved")
    else . end |
    if [.[] | select(.metadata.name == "deny-ingress-resources") |
        .spec.matchConstraints.resourceRules] !=
       [[{apiGroups:["networking.k8s.io"], apiVersions:["v1"],
          operations:["CREATE", "UPDATE"], resources:["ingresses"]}]] then
      error("Ingress validation must only match Ingress creation and updates, not Gateway API resources or deletion")
    else . end
  ' |
  yq -p=json -oy '.[] | split_doc' > "$test_dir/policies.yaml"

jq -n '
  def pod($name):
    {apiVersion:"v1", kind:"Pod", metadata:{name:$name, namespace:"policy-test"},
     spec:{containers:[{name:"app", image:"busybox:1.37", imagePullPolicy:"IfNotPresent"}]}};
  def deployment($name; $namespace):
    {apiVersion:"apps/v1", kind:"Deployment",
     metadata:{name:$name, namespace:$namespace, uid:"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"},
     spec:{selector:{matchLabels:{app:$name}},
           template:{metadata:{labels:{app:$name}}, spec:{containers:[{name:"app", image:"busybox:1.37"}]}}}};
  def workload($kind; $name; $namespace):
    if $kind == "Pod" then pod($name) | .metadata.namespace = $namespace
    else
      deployment($name; $namespace) | .kind = $kind |
      if $kind == "StatefulSet" then .spec.serviceName = $name
      elif $kind == "ReplicationController" then
        .apiVersion = "v1" | .spec.selector = .spec.selector.matchLabels
      elif $kind == "Job" then
        .apiVersion = "batch/v1" | del(.spec.selector) | .spec.template.spec.restartPolicy = "Never"
      elif $kind == "CronJob" then
        .apiVersion = "batch/v1" |
        .spec = {schedule:"0 * * * *", jobTemplate:{spec:{template:.spec.template}}} |
        .spec.jobTemplate.spec.template.spec.restartPolicy = "Never"
      else . end
    end;
  def result($type; $policy; $name; $kind; $result):
    {policy:$policy, resources:[$name], kind:$kind, result:$result,
     ("is" + $type + "Policy"):true};

  ("sha256:" + ("a" * 64)) as $digest |
  [
    {name:"pinned", image:"busybox:1.37", pull:"IfNotPresent", result:"pass"},
    {name:"latest-always", image:"busybox:latest", pull:"Always", result:"pass"},
    {name:"latest-never", image:"busybox:latest", pull:"Never", result:"fail"},
    {name:"untagged-never", image:"busybox", pull:"Never", result:"fail"},
    {name:"untagged-always", image:"busybox", pull:"Always", result:"pass"},
    {name:"port-untagged", image:"registry.example:5000/team/app", pull:"Never", result:"fail"},
    {name:"port-latest", image:"registry.example:5000/team/app:latest", pull:"Never", result:"fail"},
    {name:"port-pinned", image:"registry.example:5000/team/app:1.0", pull:"IfNotPresent", result:"pass"},
    {name:"digest", image:("registry.example:5000/team/app@" + $digest), pull:"IfNotPresent", result:"pass"},
    {name:"latest-digest", image:("busybox:latest@" + $digest), pull:"IfNotPresent", result:"pass"}
  ] as $images |
  (["containers", "initContainers", "ephemeralContainers"] |
    map(. as $field | $images[] | . + {field:$field, name:($field + "-" + .name)})) as $image_cases |
  [
    {name:"cpu-absent", field:"containers", cpu:false, result:"pass"},
    {name:"cpu-main", field:"containers", cpu:true, result:"fail"},
    {name:"cpu-init", field:"initContainers", cpu:true, result:"fail"},
    {name:"cpu-ephemeral", field:"ephemeralContainers", cpu:true, result:"fail"},
    {name:"cpu-sidecar", field:"initContainers", cpu:true, sidecar:true, result:"fail"}
  ] as $cpu_cases |
  [
    (["Deployment", "StatefulSet"][] as $kind |
      ["labels", "expressions", "mixed"][] as $selector |
      deployment(
        if $kind == "Deployment" and $selector == "labels" then "spread"
        else "spread-" + ($kind | ascii_downcase) + "-" + $selector end;
        "policy-test") |
      .kind = $kind |
      (if $kind == "StatefulSet" then .spec.serviceName = .metadata.name else . end) |
      if $selector == "expressions" then
        .spec.selector = {matchExpressions:[{key:"app", operator:"In", values:[.metadata.name]}]}
      elif $selector == "mixed" then
        .spec.selector.matchExpressions = [{key:"tier", operator:"In", values:["backend"]}] |
        .spec.template.metadata.labels.tier = "backend"
      else . end)
  ] as $spread_workloads |
  [
    $spread_workloads[],
    (deployment("opt-out"; "policy-test") | .metadata.labels = {"feddema.dev/vpa-autogen":"false"}),
    (["kube-system", "kyverno", "longhorn-system", "kube-public", "kube-node-lease"][] as $ns |
      deployment("excluded-" + $ns; $ns)),
    (deployment("deleting"; "policy-test") |
      .metadata.deletionTimestamp = "2026-10-27T20:00:00Z" |
      .metadata.finalizers = ["test.example/cleanup"]),
    (deployment("custom-spread"; "policy-test") |
      .spec.template.spec.topologySpreadConstraints = [{
        maxSkew:2, topologyKey:"kubernetes.io/hostname", whenUnsatisfiable:"ScheduleAnyway",
        labelSelector:{matchLabels:{app:"custom-spread"}}
      }])
  ] as $workloads |
  [
    (["Deployment", "StatefulSet", "DaemonSet"][] as $kind |
      ["absent", "empty", "other", "Prometheus", "Alertmanager", "ThanosRuler", "deleting"][] as $owner |
      workload($kind; "history-" + ($kind | ascii_downcase) + "-" + ($owner | ascii_downcase); "policy-test") |
      .spec.revisionHistoryLimit = 10 |
      if $owner == "empty" then .metadata.ownerReferences = []
      elif $owner == "deleting" then
        .metadata.deletionTimestamp = "2026-10-27T20:00:00Z" |
        .metadata.finalizers = ["test.example/cleanup"]
      elif $owner != "absent" then
        .metadata.ownerReferences = [{
          apiVersion:"monitoring.coreos.com/v1", kind:$owner, name:"owner",
          uid:"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        }]
      else . end)
  ] as $history_workloads |
  [
    (["Pod", "Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "ReplicationController", "Job", "CronJob"][] as $kind |
      ["default", "policy-test"][] as $namespace |
      workload($kind; "namespace-" + ($kind | ascii_downcase) + "-" + $namespace; $namespace))
  ] as $namespace_workloads |
  [
    {name:"no-probe", probe:null, result:"fail"},
    {name:"readiness", probe:"readinessProbe", result:"pass"},
    {name:"liveness", probe:"livenessProbe", result:"pass"},
    {name:"startup", probe:"startupProbe", result:"pass"}
  ] as $probe_cases |
  [
    {name:"service-default", type:null, result:"pass"},
    {name:"service-clusterip", type:"ClusterIP", result:"pass"},
    {name:"service-nodeport", type:"NodePort", result:"fail"},
    {name:"service-loadbalancer", type:"LoadBalancer", result:"pass"},
    {name:"service-externalname", type:"ExternalName", result:"pass"}
  ] as $service_cases |
  [
    (["StatefulSet", "DaemonSet"][] as $kind |
      workload($kind; "generate-" + ($kind | ascii_downcase); "policy-test"))
  ] as $generation_workloads |
  [
    (["Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "ReplicationController", "Job", "CronJob"][] as $kind |
      ["pass", "fail"][] as $expected |
      workload($kind; "autogen-" + ($kind | ascii_downcase) + "-" + $expected; "policy-test") |
      (if $kind == "CronJob" then .spec.jobTemplate.spec.template.spec else .spec.template.spec end) as $spec |
      ($spec | .containers[0].image = "busybox:latest" |
        .containers[0].imagePullPolicy = (if $expected == "pass" then "Always" else "Never" end) |
        if $expected == "pass" then .containers[0].readinessProbe = {exec:{command:["true"]}}
        else .containers[0].resources.limits.cpu = "1" end) as $updated |
      if $kind == "CronJob" then .spec.jobTemplate.spec.template.spec = $updated
      else .spec.template.spec = $updated end)
  ] as $autogen_workloads |
  {
    resources: (
      [$image_cases[] | . as $case | pod($case.name) |
        .spec[$case.field] = [{name:"test", image:$case.image, imagePullPolicy:$case.pull}]] +
      [$cpu_cases[] | . as $case | pod($case.name) |
        .spec[$case.field] = [({name:"test", image:"busybox:1.37"} +
          (if $case.cpu then {resources:{limits:{cpu:"1"}}} else {} end) +
          (if $case.sidecar then {restartPolicy:"Always"} else {} end))]] +
      $workloads + $history_workloads + $namespace_workloads + $generation_workloads + $autogen_workloads +
      [$probe_cases[] | . as $case | pod($case.name) |
        if $case.probe != null then
          .spec.containers[0][$case.probe] = {exec:{command:["true"]}}
        else . end] +
      [(pod("mixed-probes") |
        .spec.containers[0].readinessProbe = {exec:{command:["true"]}} |
        .spec.containers += [{name:"unprobed", image:"busybox:1.37"}])] +
      [$service_cases[] | . as $case |
        {apiVersion:"v1", kind:"Service", metadata:{name:$case.name, namespace:"policy-test"},
         spec:{ports:[{port:80, targetPort:8080}]}} |
        if $case.type == "ExternalName" then .spec.type = $case.type | .spec.externalName = "example.com"
        elif $case.type != null then .spec.type = $case.type else . end] +
      [{apiVersion:"networking.k8s.io/v1", kind:"Ingress", metadata:{name:"legacy-ingress", namespace:"policy-test"},
        spec:{defaultBackend:{service:{name:"app", port:{number:80}}}}}] +
      [(pod("bare-absent")),
       (pod("bare-empty") | .metadata.ownerReferences = []),
       (pod("owned") | .metadata.ownerReferences = [{
         apiVersion:"apps/v1", kind:"ReplicaSet", name:"owner",
         uid:"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
       }])]
    ),
    results: (
      [$image_cases[] | result("Validating"; "imagepullpolicy-always";
        .name; "Pod"; .result)] +
      [$cpu_cases[] | result("Validating"; "prevent-cpu-limits";
        .name; "Pod"; .result)] +
      [$workloads[] | select(.metadata.name == "opt-out" or (.metadata.name | startswith("excluded-"))) |
        result("Generating"; "generate-vpa-for-workloads";
          .metadata.name; "Deployment"; "skip")] +
      [(result("Generating"; "generate-vpa-for-workloads"; "spread"; "Deployment"; "pass") +
        {generatedResource:"generated-spread.yaml", failOnMissingResources:true}),
       (result("Mutating"; "add-topology-spread-to-workloads";
          "deleting"; "Deployment"; "skip") + {operation:"UPDATE"}),
       (result("Mutating"; "add-topology-spread-to-workloads";
          "custom-spread"; "Deployment"; "skip"))] +
      [$spread_workloads[] |
        result("Mutating"; "add-topology-spread-to-workloads";
          .metadata.name; .kind; "pass") +
        {patchedResources:("patched-" + .metadata.name + ".yaml"), failOnMissingResources:true}] +
      [$history_workloads[] |
        if .metadata.deletionTimestamp != null or
           ([.metadata.ownerReferences[]?.kind] | any(. == "Prometheus" or . == "Alertmanager" or . == "ThanosRuler")) then
          result("Mutating"; "set-revisionhistorylimit-zero"; .metadata.name; .kind; "skip") +
          {operation:"UPDATE"}
        else
          result("Mutating"; "set-revisionhistorylimit-zero"; .metadata.name; .kind; "pass") +
          {patchedResources:("patched-" + .metadata.name + ".yaml"), failOnMissingResources:true}
        end] +
      [$namespace_workloads[] |
        result("Validating"; "prevent-default-namespace"; .metadata.name; .kind;
          if .metadata.namespace == "default" then "fail" else "pass" end)] +
      [$probe_cases[] | result("Validating"; "require-pod-probes"; .name; "Pod"; .result)] +
      [result("Validating"; "require-pod-probes"; "mixed-probes"; "Pod"; "fail")] +
      [$service_cases[] | result("Validating"; "prevent-nodeport"; .name; "Service"; .result)] +
      [result("Validating"; "deny-ingress-resources"; "legacy-ingress"; "Ingress"; "fail"),
       (result("Validating"; "deny-ingress-resources"; "legacy-ingress"; "Ingress"; "fail") +
        {operation:"UPDATE"})] +
      [$generation_workloads[] |
        result("Generating"; "generate-vpa-for-workloads"; .metadata.name; .kind; "pass") +
        {generatedResource:("generated-" + .metadata.name + ".yaml"), failOnMissingResources:true}] +
      [$autogen_workloads[] | . as $workload |
        ["imagepullpolicy-always", "prevent-cpu-limits", "require-pod-probes"][] as $policy |
        result("Validating"; $policy; $workload.metadata.name; $workload.kind;
          if .metadata.name | endswith("-pass") then "pass" else "fail" end)] +
      (["bare-absent", "bare-empty", "owned"] | map(
        result("Deleting"; "clean-bare-pods"; .; "Pod";
          if . == "owned" then "fail" else "pass" end)))
    )
  }
' > "$test_dir/cases.json"

yq -p=json -oy '.resources[] | split_doc' "$test_dir/cases.json" > "$test_dir/resources.yaml"
patched_names="$(jq -er '
  .results[] | select(has("patchedResources")) |
  .resources[]
' "$test_dir/cases.json")"
while IFS= read -r name; do
  patched_file="$test_dir/patched-$name.yaml"
  patched_files+=("$patched_file")
  jq -e --arg name "$name" '
    .resources[] | select(.metadata.name == $name) |
    .metadata.labels["app.kubernetes.io/managed-by"] = "kyverno" |
    if $name | startswith("history-") then .spec.revisionHistoryLimit = 0
    else
      .spec.selector as $selector |
      .spec.template.spec.topologySpreadConstraints = (
        ["kubernetes.io/hostname", "topology.kubernetes.io/zone"] |
        map({maxSkew:1, topologyKey:., whenUnsatisfiable:"ScheduleAnyway", labelSelector:$selector})
      )
    end
  ' "$test_dir/cases.json" > "$patched_file"
done <<< "$patched_names"

generated_names="$(jq -er '.results[] | select(has("generatedResource")) | .resources[]' "$test_dir/cases.json")"
while IFS= read -r name; do
  generated_file="$test_dir/generated-$name.yaml"
  patched_files+=("$generated_file")
  jq -e --arg name "$name" '
    .resources[] | select(.metadata.name == $name) |
    {apiVersion:"autoscaling.k8s.io/v1", kind:"VerticalPodAutoscaler",
     metadata:{name:.metadata.name, namespace:.metadata.namespace, labels:{"generated-by":"kyverno"},
       ownerReferences:[{apiVersion, kind, name:.metadata.name, uid:.metadata.uid,
                         controller:true, blockOwnerDeletion:true}]},
     spec:{targetRef:{apiVersion, kind, name:.metadata.name}, updatePolicy:{updateMode:"Off"}}}
  ' "$test_dir/cases.json" > "$generated_file"
done <<< "$generated_names"

policy_names="$(jq -er '.results | map(.policy) | unique[]' "$test_dir/cases.json")"
failed_policies=0
while IFS= read -r name; do
  policy_name="$name" yq 'select(.metadata.name == strenv(policy_name))' "$test_dir/policies.yaml" > "$test_dir/policy.yaml"
  jq --arg policy "$name" '{
    apiVersion:"cli.kyverno.io/v1alpha1", kind:"Test", metadata:{name:$policy},
    policies:["policy.yaml"], resources:["resources.yaml"],
    results:[.results[] | select(.policy == $policy)]
  }' "$test_dir/cases.json" > "$test_dir/kyverno-test.yaml"
  if ! kyverno test "$test_dir" --detailed-results --warnings-as-errors; then
    printf 'Policy regression failed: %s\n' "$name" >&2
    failed_policies=$((failed_policies + 1))
  fi
done <<< "$policy_names"

if ((failed_policies > 0)); then
  printf 'Regression failures in %s policies\n' "$failed_policies" >&2
  exit 1
fi
jq -r '"All \(.results | map(.policy) | unique | length) policies passed \(.results | length) regression expectations."' "$test_dir/cases.json"
