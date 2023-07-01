
# -- Config.json & Data.json -- #

# Gets the PowerShell Profile Directory
$ProfileDirectory = Split-Path -Parent -Path $PROFILE

# Creates the expected paths for the JSON files
$JSONConfigPath = Join-Path -Path $ProfileDirectory -ChildPath 'config.json'
$JSONDataPath   = Join-Path -Path $ProfileDirectory -ChildPath 'data.json'

# Creates the Config JSON file if it don't exist
if (!(Test-Path -LiteralPath $JSONConfigPath)) {
    # The default starting body of the JSON file
    $JSONConfigBody = @{
        PowerShell = @{
            defaultModuleUpdateFrequency = 7
            modules = @()
        }
    }

    # Creates the file as it doesn't exist
    New-Item -ItemType File -Path $JSONConfigPath
    # Sets the default body of the JSON file
    Set-Content -Path $JSONConfigPath -Value ($JSONConfigBody | ConvertTo-Json)
    Remove-Variable -Name JSONConfigBody
}

# Creates the Data JSON file if it don't exist
if (!(Test-Path -LiteralPath $JSONDataPath)) {
    # The default starting body of the JSON file
    $JSONDataBody = @{}

    # Creates the file as it doesn't exist
    New-Item -ItemType File -Path $JSONDataPath
    # Sets the default body of the JSON file
    Set-Content -Path $JSONDataPath -Value ($JSONDataBody | ConvertTo-Json)
    Remove-Variable -Name JSONDataBody
}

# Gets the contents of the JSON file (as they should exist now!)
# Stores in a variable for later use
$JSONConfig = Get-Content -Path $JSONConfigPath | ConvertFrom-Json
$JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json
# Remove-Variable -Name JSONConfigPath, JSONDataPath                    No sure if I'll need these.

# Sets the Default Path to where Repositories are stored
$DefaultPath = "C:\Users\${env:username}\Documents\Repos\"
If (Test-Path $DefaultPath) {
    Set-Location $DefaultPath
} else {
    New-Item -ItemType Directory -Path $DefaultPath
    Set-Location $DefaultPath
}

# -- Functions -- #
function Import-ModuleIfInstalled($ModuleName) {
    if ((Get-module -ListAvailable -Name $ModuleName).count -gt 0) {
        Write-Host "Importing module: $ModuleName"
        Import-Module -Name $ModuleName
    }
}

function Start-ModuleVersionCheck($ModuleName) {
    if ((Get-module -ListAvailable -Name $ModuleName).count -gt 0) {
        Write-Host "Checking module version: $ModuleName"

        Start-Job -Name ("VersionChecker-$ModuleName") -ArgumentList $ModuleName -ScriptBlock {
            param( $ModuleName )
            $module = Get-InstalledModule -Name $ModuleName
            $remoteModule = Find-Module -Name $ModuleName

            if ($module.Version -ne $remoteModule.Version) {
                return $true
            }
            else {
                return $false
            }
        } | Out-Null
    }
}

# -- Module Imports -- #
Import-ModuleIfInstalled("Terminal-Icons")
Import-ModuleIfInstalled("Az.Accounts")         # Only a subnet of modules are imported to speed up startup
Import-ModuleIfInstalled("Az.Resources")

# -- Moudle Version Checks -- #
$InstalledModules = Get-InstalledModule | Where-Object Name -NotLike Az.*
foreach ($module in $InstalledModules) {
    Start-ModuleVersionCheck -ModuleName $module.Name
}
Write-Host ("Waiting for version checks to complete...")
$Jobs = Get-Job

while ($Jobs.State -contains "Running") {
    $Jobs = Get-Job
    Start-Sleep -Seconds 1
}

foreach ($Job in $Jobs) {
    if (Receive-Job -Keep -Id $Job.Id) {
        Write-Host ("⚠️ Update available for module: " + $($job.Name.Replace("VersionChecker-", "")))
        Write-Host ("⚡ To update use: Update-Module -Name " + $($job.Name.Replace("VersionChecker-", "")))
    }
    Remove-Job -Name $Job.Name
}

# -- Oh-My-Posh -- #
$ompVersion = oh-my-posh version
if ($null -ne $ompVersion) {
    
    Write-Host ("⚡ Attempting to update Oh-My-Posh!")
    winget upgrade JanDeDobbeleer.OhMyPosh -s winget | Out-Null

    $ompVersionPostUpgrade = oh-my-posh version
    if ($ompVersion -ne $ompVersionPostUpgrade) {
        Write-Host ("ℹ️ Oh-My-Posh updated from version ${ompVersion} to ${ompVersionPostUpgrade}!")
    }
    else {
        Write-Host ("⚡ Oh-My-Posh already up to date!")
    }
}
else {
    Write-Host ("⚡ Installing Oh-My-Posh!")
    winget install JanDeDobbeleer.OhMyPosh -s winget | Out-Null
}

Write-Host ("⚡ Starting Oh-My-Posh!")
oh-my-posh --init --shell pwsh --config "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expression
