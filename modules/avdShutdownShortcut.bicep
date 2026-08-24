import { setAvdShutdownShortcutScript } from 'shutdownShortcutScript.bicep'

// Legt die Desktop-Verknuepfung "AVD herunterfahren" auf einem BESTEHENDEN
// Session Host an. Wird von avdDeallocateStandalone.bicep verwendet; bei
// Neu-Deployments erledigt das modules/avdSessionHosts.bicep direkt.
//
// Bewusst ein Managed Run Command und keine CustomScriptExtension: der
// CustomScriptExtension-Handler ist pro Windows-VM nur einmal moeglich und
// bereits von "RegisterSessionHost" belegt.
@description('Name der bestehenden Session-Host-VM')
param vmName string

@description('Region der VM')
param location string

@description('Callback-URL des Deallocate-Workflows inklusive SAS-Signatur')
@secure()
param webhookUrl string

@description('Anzeigename der Desktop-Verknuepfung')
param shortcutName string = 'AVD herunterfahren'

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

resource shutdownShortcut 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm
  name: 'CreateAvdShutdownShortcut'
  location: location
  properties: {
    asyncExecution: false
    timeoutInSeconds: 300
    // Ein fehlgeschlagenes Icon darf das Deployment nicht scheitern lassen.
    treatFailureAsDeploymentFailure: false
    source: {
      script: setAvdShutdownShortcutScript
    }
    parameters: [
      {
        name: 'ShortcutName'
        value: shortcutName
      }
    ]
    // Verschluesselt, damit die SAS-URL nicht im Klartext in den Run-Command-Properties steht.
    protectedParameters: [
      {
        name: 'WebhookUrl'
        value: webhookUrl
      }
    ]
  }
}
