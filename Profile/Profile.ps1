# -- Settings -- #
$DefaultPath = "C:\Users\${env:username}\Documents\Repos\"
$DefaultPowerShellModuleUpdateChecks = 7

# -- Sets Default Directory -- #
If (Test-Path $DefaultPath) {
    Set-Location $DefaultPath
}
else {
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

function Get-PathSeperator {
    if ((Get-Location).Path -match "\\") {
        return "\"
    }
    if ((Get-Location).Path -match "/") {
        return "/"
    }
}

# -- Module Imports -- #

# Gets the directory of $PROFILE
$PathSeperator = Get-PathSeperator
$ProfileDirectory = $PROFILE.Replace( $PROFILE.split($PathSeperator)[$PROFILE.split($PathSeperator).count - 1], '' )

# Create ModuleUpdates.json if it doesn't exist
# This is where we store information about when we last checked for PowerShell module updates
if (!(Test-Path -Path "$ProfileDirectory\ModuleUpdates.json")) {
    New-Item -ItemType File -Path "$ProfileDirectory\ModuleUpdates.json"
    # Adds the date from 7 days ago forcing an update on the first run.
    Add-Content -Path "$ProfileDirectory\ModuleUpdates.json" -Value "{`"devices`": [{`"$(hostname)`": {`"lastChecked`": `"$((Get-Date).AddDays(-$DefaultPowerShellModuleUpdateChecks))`"}}]}"
}
else { Write-Verbose "ModuleUpdates.json exists!" }

# Double checks that the file exists
if (Test-Path -Path "$ProfileDirectory\ModuleUpdates.json") {
    if ($ModuleUpdatesContents.devices.$env:computername) {
        # Gets the contents of the ModuleUpdates.json file and converts into a PowerShell object
        $ModuleUpdatesContents = Get-Content ("{0}ModuleUpdates.json" -f $ProfileDirectory) | ConvertFrom-Json

        #Gets the date from the last time we checked for updates
        $ModulesLastChecked = $ModuleUpdatesContents.devices.$env:computername.lastChecked
    }
    else {
        # We should add this computer to the existing JSON file
        # Takes away $DefaultPowerShellModuleUpdateChecks to force an update on the first run.
        Add-Content -Path "$ProfileDirectory\ModuleUpdates.json" -Value "{`"devices`": [{`"$(hostname)`": {`"lastChecked`": `"$((Get-Date).AddDays(-$DefaultPowerShellModuleUpdateChecks))`"}}]}"

        $ModuleUpdatesContents = Get-Content ("{0}ModuleUpdates.json" -f $ProfileDirectory) | ConvertFrom-Json
        $ModulesLastChecked = $ModuleUpdatesContents.devices.$env:computername.lastChecked
    }
}

if ($ModulesLastChecked -lt (Get-Date).AddDays(-$DefaultPowerShellModuleUpdateChecks)) {
    Write-Host "Checking for module updates..."
    #$InstalledModules = Get-InstalledModule | Where-Object Name -NotLike Az.*

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
            Write-Host ("⚠️ Update available for module: " + $($job.Name.Replace("VersionChecker-", "")) + '. Attempting to update.')
            #Write-Host ("⚡ To update use: Update-Module -Name " + $($job.Name.Replace("VersionChecker-", "")))
            Update-Module -Name $($job.Name.Replace("VersionChecker-", ""))
        }
        Remove-Job -Name $Job.Name
    }

    # Updates the ModuleUpdates.json file with the current date
    $ModuleUpdatesContents.devices.$env:computername.lastChecked = (Get-Date)
    $ModuleUpdatesContents | ConvertTo-Json -Depth 4 | Set-Content -Path "$ProfileDirectory\ModuleUpdates.json"
}

# -- Module Imports -- #
Import-ModuleIfInstalled("Terminal-Icons")
Import-ModuleIfInstalled("Az.Accounts")         # Only a subnet of modules are imported to speed up startup
Import-ModuleIfInstalled("Az.Resources")


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

Write-Host ("⚡ Starting Oh-My-Posh!")
oh-my-posh --init --shell pwsh --conf

Write-Host ("⚡ Starting Oh-My-Posh!")
oh-my-posh --init --shell pwsh --config "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expressionoh-my-posh --init --shell pwsh --config "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expressionig "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expressionoh-my-posh --init --shell pwsh --config "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expression
