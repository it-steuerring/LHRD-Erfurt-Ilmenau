// Before script execution, create a resource group in the azure subscription "rg-avd-prod-01", then start azure cloud shell and upload files with folder structure
// Deployment parameters
@description('Location to depoloy all resources. Leave this value as-is to inherit the location from the parent resource group.')
param location string = 'germanywestcentral'

// Virtual network parameters. Change "virtualNetworkAddressSpace" and corresponding "subnetAddressRange" to fit your needs.
@description('Name for the virtual network.')
param virtualNetworkName string = 'vnet-avd-prod-01'
@description('Address space for the virtual network, in IPv4 CIDR notation.')
param virtualNetworkAddressSpace string = '10.0.0.0/16'
@description('Name for the default subnet in the virtual network.')
param subnetName string = 'default-subnet'
@description('Address range for the default subnet, in IPv4 CIDR notation.')
param subnetAddressRange string = '10.0.0.0/24'
@description('Public IP address of your local machine, in IPv4 CIDR notation. Used to restrict remote access to resources within the virtual network.')
param allowedSourceIPAddress string = '0.0.0.0/0'

// nat gateway parameters
param natGatewayName string = 'natgw-az-prod-01'
param natPublicIpName string = 'pip-natgw-prod-01'

// Virtual machine parameters for domain controller
@description('Name for the domain controller virtual machine.')
param domainControllerName string = 'vm-dc-prod-01'

// Virtual machine size for the domain controller
@description('Virtual machine size for the domain controller.')
@allowed([
  'Standard_D2s_v6'
  'Standard_B2s'
])
param virtualMachineSizeDC string = 'Standard_B2s'

// Domain parameters
// Domain names like "ad.contoso.local" are not supported. Use a simple domain like "contoso.local" instead.
// Always use .local as the top-level domain
@description('FQDN for the Active Directory domain (e.g. contoso.local).')
@minLength(3)
@maxLength(255)
param domainFQDN string = 'exaktimmobilienverwaltung.local' //change domain here. Use simple domain like "contoso.local" instead of "ad.contoso.local". Always use .local as the top-level domain

@description('URL to the FSLogix GPO.')
param fslogixProfileSizeZipUrl string = 'https://raw.githubusercontent.com/alangerotaouh/avd/main/FSLogixAvd.zip'
// currently not used
//param domainSuffix string = 'contoso.com'

// AVD parameters. Default is avd session host with pre-installed office suite. If you want to use a different image, change the "avdSessionHostOffer" and "avdSessionHostSku" parameters.
param avdHostPoolName string = 'avd-hostpool-prod-01'
param avdRegistrationExpirationTime string = dateTimeAdd(utcNow(), 'P7D')
param avdSessionHostPrefix string = 'sh-'
param avdSessionHostCount int = 1 // Number of AVD session hosts to deploy. Change this value to fit your needs.
param avdSessionHostSize string = 'Standard_E2_v5'
param avdSessionHostPublisher string = 'MicrosoftWindowsDesktop'
param avdSessionHostOffer string = 'office-365' // change to 'windows-11' for a vanilla Windows 11 image with param avdSessionHostSku
param avdSessionHostSku string = 'win11-25h2-avd-m365'  // change to 'win11-24h2-pro' for a vanilla Windows 11 image - https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-azure-marketplace?view=azloc-2606&tabs=azurecli
param avdSessionHostVersion string = 'latest'
param avdSessionHostStorageAccountType string = 'StandardSSD_LRS'
param avdworkspaceName string = 'avd-workspace-prod-01'
param avdappGroupName string = 'avd-appgroup-prod-01'
param avdmaxSessionLimit int = 4 // Maximum number of concurrent sessions per AVD session host. Change this value to fit your needs.
param loadBalancerType string = 'DepthFirst' // Load balancing algorithm for the host pool. Change this value to 'DepthFirst' if you want to fill up one session host before using the next one.
var domainName = first(split(domainFQDN, '.'))
var ouPathResolved = 'OU=Server,OU=EntraSync,DC=${domainName},DC=local'

//scaling plan parameters
param scalingPlanName string = 'avd-scalingplan-prod-01'
param rampUpStartTimeHour int = 12 // Hour to start ramp-up schedule
param rampUpStartTimeMinute int = 0 // Minute to start ramp-up schedule
param rampUpMinimumHostsPct int = 20 // Minimum percentage of hosts to keep during ramp-up
param rampUpCapacityThresholdPct int = 70 // CPU usage percentage threshold to trigger ramp-up
param peakStartTimeHour int = 13 // Hour to start peak schedule
param peakStartTimeMinute int = 0 // Minute to start peak schedule
param rampDownStartTimeHour int = 22 // Hour to start ramp-down schedule
param rampDownStartTimeMinute int = 0 // Minute to start ramp-down schedule
param rampDownMinimumHostsPct int = 10 // Minimum percentage of hosts to keep during ramp-down
param rampDownCapacityThresholdPct int = 30 // CPU usage percentage threshold to trigger ramp-down
param rampDownforceLogoffUsers bool = false // Whether to force logoff users during ramp-down
param rampDownWaitTimeMinutes int = 30 // Wait time in minutes before starting ramp-down
@allowed([
  'ZeroActiveSessions'
  'ZeroSessions'
])
param rampDownStopHostsWhen string = 'ZeroActiveSessions' // Condition to stop hosts during ramp-down
param offPeakStartTimeHour int = 23 // Hour to start off-peak schedule
param offPeakStartTimeMinute int = 0 // Minute to start off-peak schedule
param scalingPlanEnabled bool = true // Whether to enable the scaling plan. Change this value to true to enable the scaling plan.
param scheduleDaysOfWeek array = [
  'Monday'
  'Tuesday'
  'Wednesday'
  'Thursday'
  'Friday'
  'Saturday'
  'Sunday'
]
param scheduleName string = 'WeeklySchedule' // Name for the schedule in the scaling plan
@description('Administrator username for both the domain controller and workstation virtual machines.')
@minLength(1)
@maxLength(20)
param adminUsername string = 'exaktadmin' // Change this value to fit your needs. Do not use "admin" or "administrator" as the username, as these are reserved usernames in Azure.

// You will need to set a strong password for the administrator account. The password must be at least 12 characters long and contain a mix of uppercase and lowercase letters, numbers, and special characters.
// The password must not contain the username or parts of the username, and it must not be a commonly used password.
// The password must not contain the domain name or parts of the domain name.
// The password must not contain the word "password" or any variations of it.
// The password must not contain the word "admin" or any variations of it.
// The password must not contain the word "administrator" or any variations of it.
@description('Administrator password for both the domain controller and workstation virtual machines.')
@minLength(12)
@maxLength(123)
@secure()
param adminPassword string

// storage Account parameters
param storageAccountName string = 'storage${uniqueString(resourceGroup().id, deployment().name)}'

// backup vault parameters
param publicNetworkAccess string = 'Enabled' // Set this value to 'Disabled' to disable public network access to the backup vault. If public network access is disabled, you will need to set up a private endpoint to access the backup vault.
param crossRegionRestore string = 'Disabled' // Set this value to 'Enabled' to enable cross-region restore for the backup vault. Cross-region restore allows you to restore backup data to a different region than the one where the backup vault is located. This can be useful for disaster recovery scenarios.
param standardTierStorageRedundancy string = 'LocallyRedundant' // Set this value to 'LocallyRedundant', 'GeoRedundant', or 'ZoneRedundant' to specify the storage redundancy option for the backup vault. Locally redundant storage (LRS) replicates your data three times within a single data center in the region. Geo-redundant storage (GRS) replicates your data to a secondary region that is hundreds of miles away from the primary region. Zone-redundant storage (ZRS) replicates your data across three availability zones in the same region.
param softDeleteRetentionPeriodInDays int = 14 // Number of days to retain soft-deleted backup data before permanent deletion.
param backupDailyRetentionInDays int = 7 // Number of days to keep daily VM backup recovery points.

// ---------- DEPLOYMENT ---------- 
// Deploy the virtual network
module virtualNetwork 'modules/network.bicep' = {
  name: 'virtualNetwork'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
    natGatewayName: natGatewayName
    natPublicIpName: natPublicIpName
  }
}

// Deploy the domain controller
module domainController 'modules/vm.bicep' = {
  name: 'domainController'
  params: {
    location: location
    subnetId: virtualNetwork.outputs.subnetId
    vmName: domainControllerName
    vmSize: virtualMachineSizeDC
    vmPublisher: 'MicrosoftWindowsServer'
    vmOffer: 'WindowsServer'
    vmSku: '2022-datacenter-g2'
    vmVersion: 'latest'
    vmStorageAccountType: 'StandardSSD_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Use PowerShell DSC to deploy Active Directory Domain Services on the domain controller
resource domainControllerConfiguration 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${domainControllerName}/Microsoft.Powershell.DSC'
  dependsOn: [
    domainController
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      useExisting: false
      ModulesUrl: 'https://raw.githubusercontent.com/alangerotaouh/avd/refs/heads/main/Deploy-DomainServices.zip'
      ConfigurationFunction: 'Deploy-DomainServices.ps1\\Deploy-DomainServices'
      Properties: {
        domainFQDN: domainFQDN
        fslogixProfileSizeZipUrl: fslogixProfileSizeZipUrl
//        domainSuffix: domainSuffix
        adminCredential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
          adminPassword: adminPassword
      }
    }
  }
}
  
// Update the virtual network with the domain controller as the primary DNS server
module virtualNetworkDNS 'modules/network.bicep' = {
  name: 'virtualNetworkDNS'
  dependsOn: [
    domainControllerConfiguration
  ]
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
    dnsServerIPAddress: domainController.outputs.privateIpAddress
    natGatewayName: natGatewayName
    natPublicIpName: natPublicIpName
  }
}


// Deploy AVD Host Pool
module avdHostPool 'modules/avdHostPool.bicep' = {
  name: 'avdHostPool'
  dependsOn: [ virtualNetworkDNS ]
  params: {
    //location: location
    hostPoolName: avdHostPoolName
    hostPoolFriendlyName: avdHostPoolName
    hostPoolType: 'Pooled'
    loadBalancerType: loadBalancerType
    maxSessionLimit: avdmaxSessionLimit
    registrationInfoExpirationTime: avdRegistrationExpirationTime
    personalDesktopAssignmentType: 'Desktop'
    hostPoolDescription: 'AVDHostPool'
    avdworkspaceName: avdworkspaceName
    avdappGroupName: avdappGroupName
    scalingPlanName: scalingPlanName
    rampUpStartTimeHour: rampUpStartTimeHour
    rampUpStartTimeMinute: rampUpStartTimeMinute
    rampUpMinimumHostsPct: rampUpMinimumHostsPct
    rampUpCapacityThresholdPct: rampUpCapacityThresholdPct
    peakStartTimeHour: peakStartTimeHour
    peakStartTimeMinute: peakStartTimeMinute
    rampDownStartTimeHour: rampDownStartTimeHour
    rampDownStartTimeMinute: rampDownStartTimeMinute
    rampDownMinimumHostsPct: rampDownMinimumHostsPct
    rampDownCapacityThresholdPct: rampDownCapacityThresholdPct
    rampDownforceLogoffUsers: rampDownforceLogoffUsers
    rampDownWaitTimeMinutes: rampDownWaitTimeMinutes
    rampDownStopHostsWhen: rampDownStopHostsWhen
    offPeakStartTimeHour: offPeakStartTimeHour
    offPeakStartTimeMinute: offPeakStartTimeMinute
    scalingPlanEnabled: scalingPlanEnabled
    scheduleName: scheduleName
    scheduleDaysOfWeek: scheduleDaysOfWeek
  }
}

// Deploy AVD Session Hosts
module avdSessionHosts 'modules/avdSessionHosts.bicep' = [for i in range(0, avdSessionHostCount): {
  name: 'avdsh${i}'
  params: {
    location: location
    vmName: '${avdSessionHostPrefix}${i}'
    subnetId: virtualNetwork.outputs.subnetId
    vmSize: avdSessionHostSize
    vmPublisher: avdSessionHostPublisher
    vmOffer: avdSessionHostOffer
    vmSku: avdSessionHostSku
    vmVersion: avdSessionHostVersion
    osDiskType: avdSessionHostStorageAccountType
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainFQDN: domainFQDN
    domainJoinUser: adminUsername
    domainJoinPassword: adminPassword
    hostPoolId: avdHostPool.outputs.hostPoolId
    registrationInfoToken: avdHostPool.outputs.registrationInfoToken
    storageAccountName: storageAccountName
    ouPath: ouPathResolved
  }
}]
module storageModule './modules/storageAccount.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}


var backupProtectedVmName = domainControllerName
var backupProtectedVmResourceId = resourceId('Microsoft.Compute/virtualMachines', backupProtectedVmName)

module backupvlt './modules/backupvlt.bicep' = {
  name: 'backupvaultDeployment'
  dependsOn: [
    domainController
  ]
  params: {
    location: location
    publicNetworkAccess: publicNetworkAccess
    crossRegionRestore: crossRegionRestore
    standardTierStorageRedundancy: standardTierStorageRedundancy
    softDeleteRetentionPeriodInDays: softDeleteRetentionPeriodInDays
    backupDailyRetentionInDays: backupDailyRetentionInDays
    protectedVmName: backupProtectedVmName
    protectedVmResourceId: backupProtectedVmResourceId
  }
}

// Use PowerShell DSC to deploy language and disk settings on the domain controller
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = { 
  name: '${domainControllerName}/Microsoft.Powershell.CustomScriptExtension'
  location: location
  dependsOn:[virtualNetworkDNS]
  properties:{ 
    publisher:'Microsoft.Compute'
    type:'CustomScriptExtension'
    typeHandlerVersion:'1.10'
    autoUpgradeMinorVersion: true
      settings:{ 
        fileUris:[]
      commandToExecute: '''
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/alangerotaouh/avd/refs/heads/main/Deploy-LanguageAndDisk.zip' -OutFile 'C:\Temp\Deploy-LanguageAndDisk.zip'; Expand-Archive -Path 'C:\Temp\Deploy-LanguageAndDisk.zip' -DestinationPath 'C:\Temp\Deploy-LanguageAndDisk' -Force; & 'C:\Temp\Deploy-LanguageAndDisk\Deploy-LanguageAndDisk.ps1'"
'''
      }
    }
  }
