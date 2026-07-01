# Ensure Az session exists (important if script runs in a new shell/session)
Import-Module Az.Accounts -ErrorAction Stop
if (-not (Get-AzContext)) {
    Connect-AzAccount -UseDeviceAuthentication
}

# variables for permissions
$SubscriptionId = (Get-AzSubscription).Id
$SubscriptionRoleName = "Storage File Data SMB Share Contributor"
$GroupSubId = (Get-AzADGroup -DisplayName AvdProfileAccess).Id
$GroupWksId = (Get-AzADGroup -DisplayName AvdAccess).Id
$WorkspaceName        = "avd-workspace-prod-01"
$WorkspaceRG          = "rg-avd-prod-01"
$WorkspaceRoleName    = "Desktop Virtualization User"  


Set-AzContext -SubscriptionId $SubscriptionId
# permission for avd service principal
$parameters = @{
    RoleDefinitionName = "Desktop Virtualization Power On Off Contributor"
    ApplicationId = "9cdead84-a844-4324-93f2-b2e6bb768d07"
    Scope = "/subscriptions/$SubscriptionId"
}

New-AzRoleAssignment @parameters

# permission for avd profiles
New-AzRoleAssignment `
  -ObjectId $GroupSubId `
  -RoleDefinitionName $SubscriptionRoleName `
  -Scope "/subscriptions/$SubscriptionId"

#permission for avd access
$parameters = @{
    ObjectId = $GroupWksId
    ResourceName = 'avd-appgroup-prod-01'
    ResourceGroupName = 'rg-avd-prod-01'
    RoleDefinitionName = 'Desktop Virtualization User'
    ResourceType = 'Microsoft.DesktopVirtualization/applicationGroups'
}

#permission assignment for avd access to the avd workspace
New-AzRoleAssignment @parameters