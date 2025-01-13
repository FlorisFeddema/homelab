targetScope = 'subscription'

param stName string = 'longhornbackups'
param containerNames string[]= ['backups', 'minio']
param email string = 'admin@feddema.dev'
param budgetAmount int = 100
param ipAddresses string[] = ['95.98.178.131']
param location string = deployment().location

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'longhorn-backups'
  location: location
}

module storageAccount './storageaccount.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    stName: stName
    location: location
    containerNames: containerNames
    ipAddresses: ipAddresses
  }
}

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'default-budget'
  properties: {
    timePeriod: {
      startDate: '2024-05-01'
    }
    timeGrain: 'Monthly'
    amount: budgetAmount
    category: 'Cost'
    notifications: {
      NotificationForExceededBudget: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 120
        contactEmails: [email]
        thresholdType: 'Forecasted'
      }
    }
  }
}
