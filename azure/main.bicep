targetScope = 'subscription'

param stName string = 'longhornbackups'
param containerName string = 'backups'
param email string = 'admin@feddema.dev'
param budgetAmount int = 100
param ipAddresses string[] = ['31.201.249.184']
param location string = deployment().location

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
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
