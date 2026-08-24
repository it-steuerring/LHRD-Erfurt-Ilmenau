// Rollenzuweisung fuer die Managed Identity der Deallocate-Logic-App in einer
// beliebigen Resource Group. Wird nur gebraucht, wenn Session-Host-VMs NICHT in
// derselben Resource Group liegen wie der Hostpool.
@description('Object ID (principalId) der System-Assigned Managed Identity der Logic App')
param principalId string

@description('Resource ID der Logic App. Wird nur als deploy-time stabiler Seed fuer den Namen der Rollenzuweisung verwendet, weil principalId ein Runtime-Wert ist und in guid() nicht erlaubt waere.')
param logicAppResourceId string

@description('GUID der Built-in-Rollendefinition, die zugewiesen wird')
param roleDefinitionId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, logicAppResourceId, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    // principalType verhindert, dass das Deployment scheitert, solange die neue
    // Identity noch nicht durch Entra ID replizert ist.
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
