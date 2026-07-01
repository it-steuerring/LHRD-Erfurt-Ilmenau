Install-Module -Name Az
Import-Module -Name Az
Connect-AzAccount -UseDeviceAuthentication
$SubscriptionId = (Get-AzSubscription).Id

$accounts = Get-AzStorageAccount
for ($i = 0; $i -lt $accounts.Count; $i++) {
    Write-Host "[$i] $($accounts[$i].StorageAccountName) (RG: $($accounts[$i].ResourceGroupName))"
}
$idx = Read-Host "Index des gewünschten Storage-Accounts"
$sa  = $accounts[$idx]
$StorageAccountName = $sa.StorageAccountName
$ResourceGroupName = $sa.ResourceGroupName

$SamAccountName = "stprofiles"
$DomainAccountType = "ComputerAccount"
$DomainName    = $env:USERDNSDOMAIN
$domainShort   = $domainName.Split('.')[0]
$OuDistinguishedName = "OU=NoEntraSync,DC=$domainShort,DC=local"

$zipUrl      = 'https://github.com/Azure-Samples/azure-files-samples/releases/download/v0.3.2/AzFilesHybrid.zip'
$zipFile     = 'C:\Temp\AzFilesHybrid.zip'
$extractPath = 'C:\Temp\AzFilesHybrid'

if (-not (Test-Path 'C:\Temp')) {
    New-Item -Path 'C:\Temp' -ItemType Directory | Out-Null
}

Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
Write-Host "Downloaded to $zipFile and extracted to $extractPath"

cd C:\Temp\AzFilesHybrid

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
.\CopyToPSPath.ps1 
Import-Module -Name AzFilesHybrid
Select-AzSubscription -SubscriptionId $SubscriptionId 

Join-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -SamAccountName $SamAccountName `
        -DomainAccountType $DomainAccountType `
        -OrganizationalUnitDistinguishedName $OuDistinguishedName