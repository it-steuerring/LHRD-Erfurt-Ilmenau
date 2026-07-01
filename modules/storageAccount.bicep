param location string
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {}
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource profilesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: 'profiles'
  parent: fileService
  properties: {
    //  optional: shareQuota: 100
  }
}

output storageAccountId string = storageAccount.id
output fileShareId       string = profilesShare.id
output storageAccountName string = storageAccount.name
