param stName string
param location string
param containerName string

resource stAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: stName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource blobservice 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  name: 'default'
  parent: stAccount
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  name: containerName
  parent: blobservice
}
