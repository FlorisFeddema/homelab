param(
    [string]$repoPath = "/home/mobrockers/git/homelab",
    [string]$talosConfigPath = "$repoPath/talosconfig",
    [bool]$upgradeControlPlane = $false,
    [bool]$upgradeWorkerPi = $false,
    [bool]$upgradeWorkerIntel = $false
)

if(-not (Get-Module powershell-yaml -ListAvailable)) {
    Install-Module powershell-yaml -Scope CurrentUser -Force
}

$nodes = Get-Content "$repoPath/talos/nodes/nodes.yaml" | ConvertFrom-Yaml

$controlPlaneImage = "factory.talos.dev/installer/e3fab82b561b5e559cdf1c0b1e5950c0e52700b9208a2cfaa5b18454796f3a7e:v1.9.0"

$piWorkerImage = "factory.talos.dev/installer/f47e6cd2634c7a96988861031bcc4144468a1e3aef82cca4f5b5ca3fffef778a:v1.9.0"

$intelWorkerImage = "factory.talos.dev/installer/61f4380f34a0191c4972e4be7a8cae730f0dd92b37ba790268c9a5433bbad39b:v1.9.0"

if(($($upgradeControlPlane, $upgradeWorkerPi, $upgradeWorkerIntel) | where-object {$_ -eq $true}).Count -gt 1) {
    Write-Host "You must specify at most one upgrade set"
    exit 1
}

if($upgradeControlPlane) {
    foreach($node in $nodes.ips.controlPlanes) {
        Write-Host "Upgrading control plane node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $controlPlaneImage --wait
    }
}

if($upgradeWorkerPi) {
    foreach($node in $nodes.ips.piWorkers) {
        Write-Host "Upgrading pi worker node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $piWorkerImage --wait --stage
    }
}

if($upgradeWorkerIntel) {
    foreach($node in $nodes.ips.intelWorkers) {
        Write-Host "Upgrading intel worker node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $intelWorkerImage --wait
    }
}
