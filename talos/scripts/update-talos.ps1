param(
    [string]$talosConfigPath = "/home/mobrockers/git/homelab/talosconfig",
    [bool]$upgradeControlPlane = $false,
    [bool]$upgradeWorkerPi = $false,
    [bool]$upgradeWorkerIntel = $false
)
$controlPlaneNodes = $(
    "10.0.10.22",
    "10.0.10.102",
    "10.0.10.111"
)
$controlPlaneImage = "factory.talos.dev/installer/e3fab82b561b5e559cdf1c0b1e5950c0e52700b9208a2cfaa5b18454796f3a7e:v1.7.1"

$piWorkerNodes = $(
    "10.0.10.12"
)
$piWorkerImage = "factory.talos.dev/installer/f47e6cd2634c7a96988861031bcc4144468a1e3aef82cca4f5b5ca3fffef778a:v1.7.1"

$intelWorkerNodes = $(
    "10.0.10.120",
    "10.0.10.243"
)
$intelWorkerImage = "factory.talos.dev/installer/930a00fbcce4d3bcd531c92e13d24412df7b676f818004fbbdfeb693e4dcb649:v1.7.1"

if(($($upgradeControlPlane, $upgradeWorkerPi, $upgradeWorkerIntel) | where-object {$_ -eq $true}).Count -gt 1) {
    Write-Host "You must specify at most one upgrade set"
    exit 1
}

if($upgradeControlPlane) {
    foreach($node in $controlPlaneNodes) {
        Write-Host "Upgrading control plane node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $controlPlaneImage --wait
    }
}

if($upgradeWorkerPi) {
    foreach($node in $piWorkerNodes) {
        Write-Host "Upgrading pi worker node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $piWorkerImage --wait
    }
}

if($upgradeWorkerIntel) {
    foreach($node in $intelWorkerNodes) {
        Write-Host "Upgrading intel worker node $node"
        talosctl upgrade --talosconfig $talosConfigPath --nodes $node --image $intelWorkerImage --wait
    }
}
