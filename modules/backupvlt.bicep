param location string
param publicNetworkAccess string
param crossRegionRestore string
param standardTierStorageRedundancy string
param softDeleteRetentionPeriodInDays int
param backupDailyRetentionInDays int
param protectedVmName string
param protectedVmResourceId string

var backupFabric = 'Azure'
var protectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${protectedVmName}'
var protectedItem = 'vm;iaasvmcontainerv2;${resourceGroup().name};${protectedVmName}'

resource backupvault 'Microsoft.RecoveryServices/vaults@2025-08-01' = {
  location: location
  name: 'backupvault-avd-prod-01'
  properties: {
    publicNetworkAccess: publicNetworkAccess
    redundancySettings: {
      crossRegionRestore: crossRegionRestore
      standardTierStorageRedundancy: standardTierStorageRedundancy
    }
    restoreSettings: {
      crossSubscriptionRestoreSettings: {
        crossSubscriptionRestoreState: 'PermanentlyDisabled'
      }
    }
    securitySettings: {
      immutabilitySettings: {
        state: 'Disabled'
      }
      softDeleteSettings: {
        enhancedSecurityState: 'Enabled'
        softDeleteRetentionPeriodInDays: softDeleteRetentionPeriodInDays
        softDeleteState: 'Enabled'
      }
    }
  }
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
}

resource backup 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-02-01' = {
  parent: backupvault
  name: 'DomainController'
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V1'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2024-01-01T23:00:00Z'
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T23:00:00Z'
        ]
        retentionDuration: {
          count: backupDailyRetentionInDays
          durationType: 'Days'
        }
      }
    }
    timeZone: 'UTC'
    instantRpRetentionRangeInDays: 2
  }
}

resource protectedVm 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  name: '${backupvault.name}/${backupFabric}/${protectionContainer}/${protectedItem}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: backup.id
    sourceResourceId: protectedVmResourceId
  }
}


