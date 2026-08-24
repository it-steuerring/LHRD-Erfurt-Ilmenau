// Logic App (Consumption), die per Webhook alle Session Hosts eines AVD-Hostpools
// deallokiert, sobald nur noch eine einzige aktive Sitzung angemeldet ist.
//
// Bewusst ohne Azure-Connectoren: es werden ausschliesslich HTTP-Actions mit der
// System-Assigned Managed Identity verwendet. Damit ist der Workflow direkt nach
// dem Deployment lauffaehig und muss nicht nachtraeglich autorisiert werden.
@description('Region der Logic App')
param location string

@description('Name der Logic App')
param logicAppName string

@description('ARM Resource ID des AVD-Hostpools, dessen Session Hosts abgeschaltet werden')
param hostPoolResourceId string

@description('Deallocate nur, wenn hoechstens so viele AKTIVE Sitzungen im Hostpool verbleiben')
@minValue(0)
@maxValue(50)
param maxRemainingActiveSessions int = 1

@description('Verbleibende aktive Sitzung vor dem Deallocate sauber abmelden (FSLogix-Profil wird korrekt ausgehaengt)')
param logoffRemainingSessions bool = true

@description('Wartezeit in Sekunden zwischen Logoff und Deallocate')
@minValue(0)
@maxValue(3600)
param logoffWaitSeconds int = 60

@description('API-Version fuer Microsoft.DesktopVirtualization')
param avdApiVersion string = '2025-10-10'

@description('API-Version fuer Microsoft.Compute')
param computeApiVersion string = '2024-07-01'

@description('Zustand des Workflows nach dem Deployment')
@allowed([
  'Enabled'
  'Disabled'
])
param workflowState string = 'Enabled'

@description('Zusaetzliche Resource Groups, in denen Session-Host-VMs liegen. Leer lassen, wenn VMs und Hostpool in derselben Resource Group liegen.')
param additionalVmResourceGroupNames array = []

// Desktop Virtualization Power On Off Contributor.
// Deckt alles ab, was der Workflow braucht: hostpools/read, hostpools/sessionhosts/read,
// hostpools/sessionhosts/usersessions/read + /delete sowie
// Microsoft.Compute/virtualMachines/read und /deallocate/action.
// Dieselbe Rolle wird in scripts/SetPermissions.ps1 bereits fuer den AVD-Service-Principal vergeben.
var powerOnOffContributorRoleId = '40c5ff49-9181-41f8-ae61-143b0e78555e'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: workflowState
    definition: loadJsonContent('avdDeallocate.workflow.json')
    parameters: {
      hostPoolResourceId: {
        value: hostPoolResourceId
      }
      avdApiVersion: {
        value: avdApiVersion
      }
      computeApiVersion: {
        value: computeApiVersion
      }
      maxRemainingActiveSessions: {
        value: maxRemainingActiveSessions
      }
      logoffRemainingSessions: {
        value: logoffRemainingSessions
      }
      logoffWaitSeconds: {
        value: logoffWaitSeconds
      }
    }
  }
}

// Rollenzuweisung in der Resource Group, in die dieses Modul deployt wird.
// Liegen Hostpool und Session-Host-VMs dort (Standardfall rg-avd-prod-01), genuegt diese eine Zuweisung.
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, logicApp.id, powerOnOffContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', powerOnOffContributorRoleId)
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Optional: dieselbe Rolle in weiteren Resource Groups, falls die VMs dort liegen.
module additionalRoleAssignments 'logicAppRoleAssignment.bicep' = [for vmResourceGroupName in additionalVmResourceGroupNames: {
  name: 'avdDeallocateRbac-${vmResourceGroupName}'
  scope: resourceGroup(vmResourceGroupName)
  params: {
    principalId: logicApp.identity.principalId
    logicAppResourceId: logicApp.id
    roleDefinitionId: powerOnOffContributorRoleId
  }
}]

// Der Trigger muss buchstaeblich "manual" heissen, damit dieser Pfad aufloest.
resource manualTrigger 'Microsoft.Logic/workflows/triggers@2019-05-01' existing = {
  parent: logicApp
  name: 'manual'
}

@description('Callback-URL des manual-Triggers inklusive SAS-Signatur. Achtung: loest den Workflow ohne weitere Authentifizierung aus.')
output webhookUrl string = manualTrigger.listCallbackUrl().value

@description('Object ID der Managed Identity der Logic App')
output principalId string = logicApp.identity.principalId

@description('Resource ID der Logic App')
output logicAppResourceId string = logicApp.id
