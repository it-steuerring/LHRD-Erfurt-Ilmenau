[CmdletBinding()]
param(
    [string] $LogicAppName = 'logic-avd-deallocate-prod-01',
    [string] $ResourceGroupName = 'rg-avd-prod-01',
    [string] $SubscriptionId,
    [string] $ShortcutName = 'AVD herunterfahren',
    [switch] $UrlOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    throw 'Az.Accounts ist nicht installiert. Bitte "Install-Module Az.Accounts" ausfuehren.'
}
Import-Module Az.Accounts -ErrorAction Stop

$context = Get-AzContext
if (-not $context) {
    throw 'Keine Azure-Anmeldung gefunden. Bitte "Connect-AzAccount" ausfuehren.'
}

if (-not $SubscriptionId) {
    $SubscriptionId = $context.Subscription.Id
}

$callbackPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Logic/workflows/$LogicAppName/triggers/manual/listCallbackUrl?api-version=2019-05-01"

Write-Verbose "Rufe Callback-URL ab: $callbackPath"
$response = Invoke-AzRestMethod -Method POST -Path $callbackPath

if ($response.StatusCode -ne 200) {
    throw "listCallbackUrl fehlgeschlagen (HTTP $($response.StatusCode)): $($response.Content)"
}

$webhookUrl = ($response.Content | ConvertFrom-Json).value
if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
    throw 'Die Antwort enthielt keine Callback-URL.'
}

if ($UrlOnly) {
    Write-Output $webhookUrl
    return
}

$desktopPath = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'
if (-not (Test-Path -LiteralPath $desktopPath)) {
    New-Item -ItemType Directory -Path $desktopPath -Force | Out-Null
}

$shortcutPath = Join-Path -Path $desktopPath -ChildPath ("{0}.url" -f $ShortcutName)

# .url-Dateien muessen ANSI/ASCII sein, UTF-8 mit BOM liest der Shell-Handler nicht.
$content = @"
[InternetShortcut]
URL=$webhookUrl
IconFile=C:\Windows\System32\shell32.dll
IconIndex=27
"@

Set-Content -LiteralPath $shortcutPath -Value $content -Encoding ASCII -Force

Write-Output "Verknuepfung geschrieben: $shortcutPath"
