$ErrorActionPreference = 'Stop'
$ProfilePath = Split-Path -Parent -Path $PROFILE
$ConfigPath = Join-Path $ProfilePath 'config.json'
$DataPath = Join-Path $ProfilePath 'data.json'

$Config = if (Test-Path -LiteralPath $ConfigPath) {
    Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}
else {
    [pscustomobject]@{
        '$schema' = './config.schema.json'
        PowerShell = [pscustomobject]@{
            moduleAutoUpdate = $true
            moduleDefaultUpdateFrequency = 7
            modules = @()
        }
        OhMyPosh = [pscustomobject]@{ updateFrequency = 7 }
        WinGet = [pscustomobject]@{ packages = @() }
    }
}
if ($null -eq $Config.PowerShell) {
    $Config | Add-Member -NotePropertyName PowerShell -NotePropertyValue ([pscustomobject]@{}) -Force
}
$Config.PowerShell | Add-Member -NotePropertyName repositoryPath -NotePropertyValue $PSScriptRoot -Force

$Data = if (Test-Path -LiteralPath $DataPath) {
    Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json
}
else {
    [pscustomobject]@{ powershellModules = @() }
}
$InstalledCommit = & git -C $PSScriptRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Unable to identify the profile repository commit.' }

$null = New-Item -ItemType Directory -Path $ProfilePath -Force
Set-Content -LiteralPath $ConfigPath -Value ($Config | ConvertTo-Json -Depth 20)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Profile/Profile.ps1') -Destination $PROFILE -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Profile') -Destination $ProfilePath -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'config.schema.json') -Destination $ProfilePath -Force

# Each PowerShell host installs a separate profile, even when data.json is shared.
if ($null -eq $Data.profileInstalledCommits) {
    $Data | Add-Member -NotePropertyName profileInstalledCommits -NotePropertyValue ([pscustomobject]@{}) -Force
}
$Data.profileInstalledCommits | Add-Member -NotePropertyName ([string]$PROFILE) -NotePropertyValue ([string]$InstalledCommit) -Force
Set-Content -LiteralPath $DataPath -Value ($Data | ConvertTo-Json -Depth 20)
