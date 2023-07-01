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
            moduleAutoUpdate = $true
            moduleDefaultUpdateFrequency = 7
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
    $JSONDataBody = @{
        powershellModules = @()
    }

    # Creates the file as it doesn't exist
    New-Item -ItemType File -Path $JSONDataPath
    # Sets the default body of the JSON file
    Set-Content -Path $JSONDataPath -Value ($JSONDataBody | ConvertTo-Json)
    Remove-Variable -Name JSONDataBody
}

# Stores the contents of the Confg and Data file into a variable (as they should exist now!)
$JSONConfig = Get-Content -Path $JSONConfigPath | ConvertFrom-Json
$JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json

# Sets the Default Path. Set to where your Repositories are stored
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

# -- Moudle Version Checks -- #

# Gets all PowerShell Modules - excluding the sub-modules of Az
$InstalledModules = Get-InstalledModule | Where-Object Name -NotLike Az.*

foreach ($module in $InstalledModules) {
    # Before we check for the last updates we need to make sure that the module is registered in the Data.json file

    # Filter information from $JSONDate to the current module
    $ModuleFromDataFile = $JSONData.powershellModules | Where-Object Name -eq $module.Name
    
    # Registers the PowerShell module to the Data file if it was not found (it's $null)
    if (!($ModuleFromDataFile)) {
        # Module is not registered in the Data.json file

        # Default body of a module in the Data.json file
        $NewModuleBody = @{
            Name = $module.Name
            LastUpdateCheck = $null
            LastUpdated = $null
        }

        # Get the contents of the file to ensure we have the latest version     
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json          # Get
        # Add the new module to the array
        $JSONData.powershellModules += $NewModuleBody                           # Set
        # Save the new array to the Data.json file
        Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)     # Save
        # Get to ensure we have the latest version, after just writing to it
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json          # Get
    }

    # Now that the module is definitely registered in the Data.json file, we can check when they were last updated.

    # If the module has not previously been checked for updates
    if ((!($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck)) {
        # Module has never been checked for updates

        # Start a job to check for an update
        Start-ModuleVersionCheck -ModuleName $module.Name
        $jobsCreated = $true # Used later during the job check

        # Set the LastUpdateCheck to the current date
        # Get the contents of the file to ensure we have the latest version     
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
        # Update the LastUpdateCheck
        ($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck = Get-Date -AsUTC  # Set
        # Save the new array to the Data.json file
        Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
        # Get to ensure we have the latest version, after just writing to it
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
    } else {    # An else is used here as we don't want to run the code below if it has just been checked because of the above if statement
        # If the module was last checked for an update more than the configured amount of days ago
        # If LastUpdateCheck -GT (LastUpdateCheck + moduleDefaultUpdateFrequency)
        if (($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck -gt ($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck.AddDays($JSONConfig.PowerShell.moduleDefaultUpdateFrequency)) {
            # Start a job to check for an update
            Start-ModuleVersionCheck -ModuleName $module.Name
            $jobsCreated = $true # Used later during the job check

            # Set the LastUpdateCheck to the current date
            # Get the contents of the file to ensure we have the latest version     
            $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
            # Update the LastUpdateCheck
            ($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck = Get-Date -AsUTC  # Set
            # Save the new array to the Data.json file
            Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
            # Get to ensure we have the latest version, after just writing to it
            $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
        } else {
            Write-Host ("⏱️ $($module.Name) has recently been checked for updates.")
        }
    }
}

# Using $jobsCreated means that we can skip this entire section if no check for updates jobs were created
if ($jobsCreated) {
    Write-Host ("Waiting for version checks to complete...")
    $Jobs = Get-Job

    # Waits for all jobs to complete
    while ($Jobs.State -contains "Running") {
        $Jobs = Get-Job
        Start-Sleep -Seconds 1
    }
    
    # Iterates through all jobs and checks if they returned true (meaning an update is available for that module)
    foreach ($Job in $Jobs) {
        if (Receive-Job -Keep -Id $Job.Id) {

            if ($JSONConfig.PowerShell.moduleAutoUpdate) {
                Write-Host ("⚡ Attempting to update module: " + $($job.Name.Replace("VersionChecker-", "")))
                Update-Module -Name $($job.Name.Replace("VersionChecker-", "")) -Verbose

                # Set the LastUpdated to the current date
                # Get the contents of the file to ensure we have the latest version     
                $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
                # Update the LastUpdateCheck
                ($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdated = Get-Date -AsUTC      # Set
                # Save the new array to the Data.json file
                Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
                # Get to ensure we have the latest version, after just writing to it
                $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get

            } else {
                Write-Host ("⚠️ Update available for module: " + $($job.Name.Replace("VersionChecker-", "")))
                Write-Host (" To update use: Update-Module -Name " + $($job.Name.Replace("VersionChecker-", "")) + ". Alternatively, set moduleAutoUpdate to true in $($JSONConfigPath). Updating manually will not update the LastUpdated property in the profile data file.")
            }
        }
        Remove-Job -Name $Job.Name
    }
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
if ($null -eq $ompVersion) {
    Write-Host ("⚡ Installing Oh-My-Posh!")
    winget install JanDeDobbeleer.OhMyPosh -s winget | Out-Null
}

# -- Module Imports -- #
Import-ModuleIfInstalled("Terminal-Icons")
Import-ModuleIfInstalled("Az.Accounts")         # Only a subnet of modules are imported to speed up startup
Import-ModuleIfInstalled("Az.Resources")
Import-ModuleIfInstalled("posh-git")

Write-Host ("⚡ Starting Oh-My-Posh!")
oh-my-posh --init --shell pwsh --config "C:\Users\${env:username}\OneDrive\Documents\PowerShell\Modules\oh-my-posh\3.177.0\themes\blue-owl.omp.json" | Invoke-Expression
