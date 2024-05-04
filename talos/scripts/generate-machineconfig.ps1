param(
    [string]$repoPath = "/home/mobrockers/git/homelab",
    [boolean]$applyConfig = $false
)

if(-not (Get-Module powershell-yaml -ListAvailable)) {
    Install-Module powershell-yaml -Scope CurrentUser -Force
}

$nodes = Get-Content "$repoPath/talos/nodes/nodes.yaml" | ConvertFrom-Yaml
$kubernetesVersion = (kubectl version -o yaml | ConvertFrom-Yaml).serverVersion.gitVersion.Replace("v", "")

$controlPlanes = $nodes.ips.controlPlanes
for ($node=0; $node -lt $controlPlanes.Count; $node++) {

    Write-Host "Generating control plane $node machineconfig"

    $endpoint = "https://$$(controlPlanes[$node]):6443"

    talosctl gen config talos-broersma $endpoint                            `
    --output $repoPath/talos/rendered/control-plane-$node.yaml              `
    --output-types controlplane                                             `
    --with-cluster-discovery=false                                          `
    --with-secrets $repoPath/secrets.yaml                                   `
    --config-patch @$repoPath/talos/patches/cluster-name.yaml               `
    --config-patch @$repoPath/talos/patches/cluster-endpoint.yaml           `
    --config-patch @$repoPath/talos/patches/disable-cni-and-kube-proxy.yaml `
    --config-patch @$repoPath/talos/patches/enable-kubeprism.yaml           `
    --config-patch @$repoPath/talos/patches/region-meijhorst.yaml           `
    --config-patch @$repoPath/talos/patches/zone-embla.yaml                 `
    --config-patch @$repoPath/talos/patches/control-plane-vip.yaml          `
    --config-patch-control-plane @$repoPath/talos/nodes/control-plane-$node.yaml          `
    --kubernetes-version $kubernetesVersion `
    --force

    if($applyConfig) {
        talosctl apply --talosconfig $repoPath/talosconfig --nodes $controlPlanes[$node] --file $repoPath/talos/rendered/control-plane-$node.yaml
    }
}

$intelWorkers = $nodes.ips.intelWorkers
for ($node=0; $node -lt $intelWorkers.Count; $node++) {

    Write-Host "Generating worker $node machineconfig"

    $endpoint = "https://$$(intelWorkers[$node]):6443"

    talosctl gen config talos-broersma $endpoint                            `
    --output $repoPath/talos/rendered/worker-$node.yaml                     `
    --output-types worker                                                   `
    --with-cluster-discovery=false                                          `
    --with-secrets $repoPath/secrets.yaml                                   `
    --config-patch @$repoPath/talos/patches/cluster-name.yaml               `
    --config-patch @$repoPath/talos/patches/cluster-endpoint.yaml           `
    --config-patch @$repoPath/talos/patches/disable-cni-and-kube-proxy.yaml `
    --config-patch @$repoPath/talos/patches/enable-kubeprism.yaml           `
    --config-patch @$repoPath/talos/patches/region-meijhorst.yaml           `
    --config-patch @$repoPath/talos/patches/zone-embla.yaml                 `
    --config-patch @$repoPath/talos/nodes/worker-$node.yaml                 `
    --kubernetes-version $kubernetesVersion `
    --force

    if($applyConfig) {
        talosctl apply --talosconfig $repoPath/talosconfig --nodes $intelWorkers[$node] --file $repoPath/talos/rendered/worker-$node.yaml
    }
}

$piWorkers = $nodes.ips.piWorkers
for ($node=0; $node -lt $piWorkers.Count; $node++) {

    Write-Host "Generating worker pi $node machineconfig"

    $endpoint = "https://$$(piWorkers[$node]):6443"

    talosctl gen config talos-broersma $endpoint                            `
    --output $repoPath/talos/rendered/worker-pi-$node.yaml                  `
    --output-types worker                                                   `
    --with-cluster-discovery=false                                          `
    --with-secrets $repoPath/secrets.yaml                                   `
    --config-patch @$repoPath/talos/patches/cluster-name.yaml               `
    --config-patch @$repoPath/talos/patches/cluster-endpoint.yaml           `
    --config-patch @$repoPath/talos/patches/disable-cni-and-kube-proxy.yaml `
    --config-patch @$repoPath/talos/patches/enable-kubeprism.yaml           `
    --config-patch @$repoPath/talos/patches/region-meijhorst.yaml           `
    --config-patch @$repoPath/talos/patches/zone-embla.yaml                 `
    --config-patch @$repoPath/talos/nodes/worker-pi-$node.yaml              `
    --kubernetes-version $kubernetesVersion `
    --force

    if($applyConfig) {
        talosctl apply --talosconfig $repoPath/talosconfig --nodes $piWorkers[$node] --file $repoPath/talos/rendered/worker-pi-$node.yaml
    }
}
