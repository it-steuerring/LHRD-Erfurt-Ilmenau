@description('Location for the session host VM')
param location string
@description('Name of the VM')
param vmName string
@description('Subnet resource ID')
param subnetId string
@description('VM size')
param vmSize string
@description('Marketplace image publisher')
param vmPublisher string
@description('Marketplace image offer')
param vmOffer string
@description('Marketplace image SKU')
param vmSku string
@description('Marketplace image version')
param vmVersion string = 'latest'
@description('OS disk type')
param osDiskType string = 'StandardSSD_LRS'
@description('Local admin username')
param adminUsername string
@secure()
@description('Local admin password')
param adminPassword string
@description('AD domain FQDN')
param domainFQDN string
@description('Domain-join user')
param domainJoinUser string
@secure()
@description('Domain-join password')
param domainJoinPassword string
@description('AVD Host Pool ARM resource ID')
param hostPoolId string
param ouPath string

@description('Registration token for the AVD host pool')
@secure()
param registrationInfoToken string

@description('Storage account name for registry settings')
param storageAccountName string

// Extract host pool name from the resource ID
var hostPoolName = last(split(hostPoolId, '/'))

// Network interface
resource nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      { name: 'ipconfig1'
        properties: {
          subnet: { id: subnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// VM
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: {
        publisher: vmPublisher
        offer: vmOffer
        sku: vmSku
        version: vmVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: osDiskType }
        diskSizeGB: 512
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        { id: nic.id }
      ]
    }
  }
}

// 1) DSC Extension for domain-join
resource dscJoin 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: 'DSCJoin'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true

    settings: {
      ModulesUrl: 'https://github.com/alangerotaouh/avd/raw/main/Join-Domain-AVD.zip'
      ConfigurationFunction: 'Join-Domain.ps1\\Join-Domain'
      Properties: {
        computerName: vmName
        domainFQDN: domainFQDN
        ouPath: ouPath
        adminCredential: {
          UserName: domainJoinUser
          Password: 'PrivateSettingsRef:domainJoinPassword'   
        }
      }
    }
    protectedSettings: {
      Items: {
        domainJoinPassword: domainJoinPassword         
      }
    }
  }
}

// 2) CustomScriptExtension to register in host pool, set fslogix settings and install language pack
resource registerHost 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: 'RegisterSessionHost'
  dependsOn: [ dscJoin ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/alangerotaouh/avd/refs/heads/main/Register-Host.zip'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Expand-Archive -Path Register-Host.zip -DestinationPath .\\RegisterHost; .\\RegisterHost\\Register-Host.ps1 -hostPoolName \'${hostPoolName}\' -registrationToken \'${registrationInfoToken}\' -storageAccountName \'${storageAccountName}\' -aadJoin \'false\'"'
    }
    protectedSettings: { }
  }
  location: location
}
