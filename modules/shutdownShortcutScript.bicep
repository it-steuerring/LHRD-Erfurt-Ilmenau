// Einzige Quelle fuer das PowerShell-Skript, das die Desktop-Verknuepfung
// "AVD herunterfahren" auf den Public Desktop eines Session Hosts schreibt.
//
// Bewusst eine exportierte Variable und nicht loadTextContent('../scripts/...'):
// damit haengt der Bicep-Build nicht am Ordner scripts/, der ausschliesslich
// manuell auszufuehrende Skripte enthaelt und deshalb nicht mit in die Cloud
// Shell hochgeladen wird. Fuer das Deployment genuegen main.bicep und modules/.
//
// Importiert von:
//   modules/avdSessionHosts.bicep    (Neu-Deployment ueber main.bicep)
//   modules/avdShutdownShortcut.bicep (Nachruesten bestehender Session Hosts)

@description('PowerShell-Skript fuer den Azure Run Command. Erwartet die Parameter WebhookUrl (protectedParameters) und ShortcutName (parameters).')
@export()
var setAvdShutdownShortcutScript = '''
<#
    Schreibt die Verknuepfung "AVD herunterfahren" auf den Public Desktop des
    Session Hosts. Laeuft als Azure Run Command im SYSTEM-Kontext, was fuer den
    Schreibzugriff auf C:\Users\Public\Desktop noetig ist.

    Achtung: Die Verknuepfung ist fuer jeden Benutzer des Session Hosts lesbar
    und die enthaltene SAS-URL loest den Deallocate-Workflow ohne weitere
    Authentifizierung aus.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $WebhookUrl,

    [string] $ShortcutName = 'AVD herunterfahren'
)

$ErrorActionPreference = 'Stop'

$desktopPath = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'
if (-not (Test-Path -LiteralPath $desktopPath)) {
    New-Item -ItemType Directory -Path $desktopPath -Force | Out-Null
}

$shortcutPath = Join-Path -Path $desktopPath -ChildPath ("{0}.url" -f $ShortcutName)

# .url-Dateien muessen ANSI/ASCII sein, UTF-8 mit BOM liest der Shell-Handler nicht.
$content = @"
[InternetShortcut]
URL=$WebhookUrl
IconFile=C:\Windows\System32\shell32.dll
IconIndex=27
"@

Set-Content -LiteralPath $shortcutPath -Value $content -Encoding ASCII -Force

Write-Output "Verknuepfung geschrieben: $shortcutPath"
'''
