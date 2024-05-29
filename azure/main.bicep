targetScope = 'subscription'

param stName string = 'longhornbackups'
param containerName string = 'backups'
param location string = deployment().location

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'longhorn-backups'
  location: location
}

module storageAccount './storageaccount.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    stName: stName
    location: location
    containerName: containerName
  }
}
