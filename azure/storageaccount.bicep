param stName string
param location string
param containerNames string[]
param ipAddresses string[]

resource stAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: stName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        for ip in ipAddresses: {
          value: ip
          action: 'Allow'
        }
      ]
    }
  }
}

resource blobservice 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  name: 'default'
  parent: stAccount
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [for containerName in containerNames: {
  name: containerName
  parent: blobservice
}]
