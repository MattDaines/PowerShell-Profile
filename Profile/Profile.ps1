# Update before initializing modules and the prompt so this session uses the new profile.
if (!(Get-Variable -Name ProfileUpdateReloading -ValueOnly -ErrorAction SilentlyContinue)) {
    $ProfileUpdated = & {
        $ErrorActionPreference = 'Stop'
        try {
            $Directory = Split-Path -Parent -Path $PROFILE
            $ConfigFile = Join-Path $Directory 'config.json'
            if (!(Test-Path -LiteralPath $ConfigFile)) { return $false }
            $Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
            $Repository = $Config.PowerShell.repositoryPath
            if ([string]::IsNullOrWhiteSpace($Repository)) { return $false }
            if (!(Test-Path -LiteralPath $Repository -PathType Container)) {
                throw "Repository directory is missing: $Repository"
            }
            $Git = (Get-Command git -CommandType Application -ErrorAction Stop).Source
            $Timer = [System.Diagnostics.Stopwatch]::StartNew()

            function Invoke-ProfileGit {
                param([string[]]$GitArguments)

                $Process = [System.Diagnostics.Process]::new()
                $Process.StartInfo.FileName = $Git
                $Process.StartInfo.UseShellExecute = $false
                $Process.StartInfo.CreateNoWindow = $true
                $Process.StartInfo.RedirectStandardOutput = $true
                $Process.StartInfo.RedirectStandardError = $true
                $Process.StartInfo.Environment['GIT_TERMINAL_PROMPT'] = '0'
                $Process.StartInfo.Environment['GCM_INTERACTIVE'] = 'Never'
                $Process.StartInfo.Environment['GIT_SSH_COMMAND'] = 'ssh -o BatchMode=yes'
                foreach ($Argument in (@('-C', $Repository, '-c', 'credential.interactive=false') + $GitArguments)) {
                    $Process.StartInfo.ArgumentList.Add($Argument)
                }
                try {
                    $Remaining = 15000 - [int]$Timer.ElapsedMilliseconds
                    if ($Remaining -le 0) { throw 'Git update exceeded 15 seconds.' }
                    $null = $Process.Start()
                    $Output = $Process.StandardOutput.ReadToEndAsync()
                    $Errors = $Process.StandardError.ReadToEndAsync()
                    if (!$Process.WaitForExit($Remaining)) {
                        $Process.Kill($true)
                        $Process.WaitForExit()
                        throw 'Git update exceeded 15 seconds.'
                    }
                    if ($Process.ExitCode -ne 0) {
                        $ErrorLine = ($Errors.GetAwaiter().GetResult().Trim() -split '\r?\n', 2)[0]
                        throw "Git $($GitArguments[0]) failed. $ErrorLine"
                    }
                    $Output.GetAwaiter().GetResult().Trim()
                }
                finally {
                    $Process.Dispose()
                }
            }

            if (Invoke-ProfileGit -GitArguments @('status', '--porcelain')) {
                throw 'The profile repository has local changes. Commit or stash them to enable updates.'
            }
            $Branch = Invoke-ProfileGit -GitArguments @('branch', '--show-current')
            if ($Branch -ne 'main') {
                # Fetch first so a missing local main can track the current origin/main.
                $null = Invoke-ProfileGit -GitArguments @('fetch', 'origin', 'main')
                $Branches = Invoke-ProfileGit -GitArguments @('branch', '--list', 'main')
                if ($Branches) {
                    $null = Invoke-ProfileGit -GitArguments @('switch', 'main')
                }
                else {
                    $null = Invoke-ProfileGit -GitArguments @('switch', '--create', 'main', '--track', 'origin/main')
                }
            }
            $null = Invoke-ProfileGit -GitArguments @('pull', '--ff-only', 'origin', 'main')
            $Commit = Invoke-ProfileGit -GitArguments @('rev-parse', 'HEAD')
            $DataFile = Join-Path $Directory 'data.json'
            $InstalledCommit = $null
            if (Test-Path -LiteralPath $DataFile) {
                $Data = Get-Content -LiteralPath $DataFile -Raw | ConvertFrom-Json
                $InstalledCommit = $Data.profileInstalledCommits.([string]$PROFILE)
            }
            if ($Commit -eq $InstalledCommit) { return $false }
            & (Join-Path $Repository 'Import-Profile.ps1')
            return $true
        }
        catch {
            Write-Warning "Profile update skipped. $($_.Exception.Message)"
            return $false
        }
    }
    if ($ProfileUpdated) {
        $ProfileUpdateReloading = $true
        try {
            . $PROFILE
        }
        finally {
            Remove-Variable -Name ProfileUpdateReloading -ErrorAction SilentlyContinue
        }
        return
    }
}

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
        '$schema' = './config.schema.json'
        PowerShell = @{
            moduleAutoUpdate = $true
            moduleDefaultUpdateFrequency = 7
            modules = @()
        }
        OhMyPosh = @{
            updateFrequency = 7
        }
        WinGet = @{
            packages = @()
        }
    }

    # Creates the file as it doesn't exist
    New-Item -ItemType File -Path $JSONConfigPath
    # Sets the default body of the JSON file
    Set-Content -Path $JSONConfigPath -Value ($JSONConfigBody | ConvertTo-Json -Depth 20)
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

# Stores the contents of the Config and Data file into a variable (as they should exist now!)
$JSONConfig = Get-Content -Path $JSONConfigPath | ConvertFrom-Json
$JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json

if ($JSONConfig.PSObject.Properties.Name -notcontains '$schema') {
    $JSONConfig | Add-Member -NotePropertyName '$schema' -NotePropertyValue './config.schema.json'
    Set-Content -LiteralPath $JSONConfigPath -Value ($JSONConfig | ConvertTo-Json -Depth 20)
}

if ($null -eq $JSONConfig.WinGet) {
    $JSONConfig | Add-Member -NotePropertyName WinGet -NotePropertyValue ([pscustomobject]@{ packages = @() }) -Force
    Set-Content -LiteralPath $JSONConfigPath -Value ($JSONConfig | ConvertTo-Json -Depth 20)
}
elseif ($JSONConfig.WinGet.PSObject.Properties.Name -notcontains 'packages') {
    $JSONConfig.WinGet | Add-Member -NotePropertyName packages -NotePropertyValue @()
    Set-Content -LiteralPath $JSONConfigPath -Value ($JSONConfig | ConvertTo-Json -Depth 20)
}

# Sets the Default Path. Set to where your Repositories are stored
If (Test-Path .git -Type Container) {
    Write-Verbose -Message ("Current location has a .git folder. Skipping Set-Location as it's likely the VS Code has opened the terminal at the correct directory.")
}
else {
    $DefaultPath = Join-Path -Path $HOME -ChildPath 'Documents/Repos'
    If (Test-Path $DefaultPath) {
        Set-Location $DefaultPath
    }
    else {
        New-Item -ItemType Directory -Path $DefaultPath
        Set-Location $DefaultPath
    }
}


# -- Functions -- #
if ($IsWindows) {
    function Start-WinGetUpdate {
        <#
        .SYNOPSIS
        Updates available WinGet packages using rules in the profile config.json.
        .DESCRIPTION
        Exact ID rules take priority over wildcard rules. Otherwise the first matching
        wildcard rule wins. updateStrategy defaults to upgrade and referenceBy to id.
        Use updateStrategy skip to leave matching packages out of the update run.
        .EXAMPLE
        Start-WinGetUpdate -WhatIf
        .EXAMPLE
        Start-WinGetUpdate
        #>
        [CmdletBinding(SupportsShouldProcess)]
        param ()

        $WinGetCommand = Get-Command winget -ErrorAction Stop
        $Config = Get-Content -LiteralPath $JSONConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $Rules = @($Config.WinGet.packages)
        $Patterns = @{}
        foreach ($Rule in $Rules) {
            if ($null -eq $Rule) { continue }
            if ([string]::IsNullOrWhiteSpace($Rule.id) -or $Patterns.ContainsKey($Rule.id)) {
                throw 'Each WinGet rule must have a nonempty, unique ID pattern.'
            }
            $Patterns[$Rule.id] = $true
            # Constructing the pattern also validates wildcard syntax before any changes.
            $null = [System.Management.Automation.WildcardPattern]::new($Rule.id, 'IgnoreCase')
            if ($Rule.updateStrategy -and $Rule.updateStrategy -notin @('upgrade', 'reinstall', 'skip')) {
                throw "Invalid updateStrategy for $($Rule.id). Use upgrade, reinstall, or skip."
            }
            if ($Rule.referenceBy -and $Rule.referenceBy -notin @('name', 'id')) {
                throw "Invalid referenceBy for $($Rule.id). Use name or id."
            }
        }

        $ListOutput = @(& $WinGetCommand list --source winget --upgrade-available)
        $ListExitCode = $LASTEXITCODE
        # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND is also an empty result.
        if ($ListExitCode -eq -1978335212) {
            Write-Host 'No WinGet updates available.'
            return
        }
        if ($ListExitCode -ne 0) {
            throw "WinGet update discovery failed with exit code $ListExitCode."
        }

        $Packages = @()
        $Columns = $null
        $PreviousLine = ''
        foreach ($OutputLine in $ListOutput) {
            $Line = ([string]$OutputLine -replace '\x1b\[[0-?]*[ -/]*[@-~]', '')
            if ($Line -match '^\s*-{3,}\s*$') {
                # WinGet pads header columns with at least two spaces, including localized headers.
                $Columns = [regex]::Matches($PreviousLine, '\S.*?(?=\s{2,}|$)')
                continue
            }
            $PreviousLine = $Line
            if (!$Columns -or $Columns.Count -lt 4 -or [string]::IsNullOrWhiteSpace($Line)) { continue }
            $Values = @()
            for ($Index = 0; $Index -lt 4; $Index++) {
                $Start = $Columns[$Index].Index
                $End = $Line.Length
                if ($Index + 1 -lt $Columns.Count) {
                    $End = [Math]::Min($End, $Columns[$Index + 1].Index)
                }
                $Values += if ($Start -lt $End) { $Line.Substring($Start, $End - $Start).Trim() } else { '' }
            }
            # Summary lines do not extend into the version columns.
            if (!$Values[1] -or !$Values[2] -or !$Values[3]) { continue }
            if (!$Values[0] -or $Values[1] -match '\s|…|\.\.\.$') {
                Write-Warning "Skipping unusable WinGet row: $Line"
                continue
            }
            $Packages += [pscustomobject]@{
                Id = $Values[1]
                Name = $Values[0]
                InstalledVersion = $Values[2]
                AvailableVersion = $Values[3]
            }
        }
        if (!$Columns -or $Columns.Count -lt 4) {
            throw 'Unable to locate the WinGet package table.'
        }
        if (!$Packages.Count) { Write-Host 'No WinGet updates available.' }

        foreach ($Package in $Packages) {
            $Rule = $Rules | Where-Object { $_.id -eq $Package.Id } | Select-Object -First 1
            if (!$Rule) {
                $Rule = $Rules | Where-Object { $_ -and $Package.Id -like $_.id } | Select-Object -First 1
            }
            $Strategy = 'upgrade'
            $ReferenceBy = 'id'
            if ($Rule.updateStrategy) { $Strategy = $Rule.updateStrategy.ToLowerInvariant() }
            if ($Strategy -eq 'skip') {
                Write-Verbose "Skipping $($Package.Id) according to its configured rule."
                continue
            }
            if ($Rule.referenceBy) { $ReferenceBy = $Rule.referenceBy.ToLowerInvariant() }
            $Reference = $Package.Id
            if ($ReferenceBy -eq 'name') { $Reference = $Package.Name }
            if ($Reference -match '…|\.\.\.$') {
                Write-Warning "Skipping $($Package.Id) because its $ReferenceBy is truncated."
                continue
            }
            if (!$PSCmdlet.ShouldProcess("$($Package.Name) [$($Package.Id)]", "$Strategy by $ReferenceBy")) { continue }

            $Operations = @('upgrade')
            if ($Strategy -eq 'reinstall') { $Operations = @('uninstall', 'install') }
            foreach ($Operation in $Operations) {
                $Arguments = @($Operation, "--$ReferenceBy", $Reference, '--exact', '--source', 'winget')
                try {
                    & $WinGetCommand @Arguments | Out-Host
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "WinGet $Operation failed for $($Package.Id) with exit code $LASTEXITCODE."
                        break
                    }
                }
                catch {
                    Write-Warning "WinGet $Operation failed for $($Package.Id): $_"
                    break
                }
            }
        }
    }
}

function Import-ModuleIfInstalled($ModuleName) {
    # If the module is installed and not already imported, we import it
    if ((Get-Module -ListAvailable -Name $ModuleName).count -gt 0 -and ($null -eq (Get-Module -Name $ModuleName))) {
        Write-Host "Importing module: $ModuleName"
        Import-Module -Name $ModuleName
    }
    else {
        Write-Verbose "Module $ModuleName is installed and already imported"
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

function Uninstall-ObsoleteModule {
    [CmdletBinding()]
    param (
        [String]$ModuleName,
        [Switch]$WhatIf
    )
    begin {
        Write-Verbose -Message ("Getting all versions of the module $ModuleName")
        $Module = Get-Module -ListAvailable -Name $ModuleName


    }
    process {
        # If there is only one version of the module, then there is no module versions to uninstall
        if ($Module.Count -eq 1) {
            Write-Verbose -Message ("There is $($Module.count) version of $ModuleName")
        }
        # If there is more than one version of the module, then there are module versions to uninstall
        # We will try to uninstall versions of the module that are not the latest version
        if ($Module.Count -gt 1) {
            Write-Verbose -Message ("There are $($Module.count) versions of $ModuleName")
            # Get all versions of the module except the latest version (Using "-Skip 1")
            $ModuleUninstallVersions = $Module | Sort-Object Version -Descending | Select-Object -Skip 1
            foreach ($ModuleVersion in $ModuleUninstallVersions) {
                # If the -WhatIf switch is used, then we will not uninstall the module but output to console
                if ($WhatIf) {
                    Uninstall-Module -Name $ModuleName -RequiredVersion $ModuleVersion.Version -WhatIf
                }
                # If the -WhatIf switch is not used, then we will uninstall the module
                else {
                    Write-Verbose -Message ("Uninstalling $($ModuleVersion.Version) of $ModuleName")
                    Uninstall-Module -Name $ModuleName -RequiredVersion $ModuleVersion.Version
                }
            }
        }
        # If there are no versions of the module, then there is nothing to do
        if (($Module.Count -eq 0) -or ($null -eq $Module)) {
            Write-Error -Message "The module is not installed."
        }
    }
    end {}
}

function Get-MyPublicIpAddress {
    <#
    .SYNOPSIS
    Returns your current public IP address as a string.

    .DESCRIPTION
    Finds your public IP address by using a web call to http://icanhazip.com or to http://ipv4.icanhazip.com for forcing an IPv4 response.

    .PARAMETER ForceIPv4
    This parameter forces the web call to http://ipv4.icanhazip.com instead of http://icanhazip.com. http://icanhazip.com can return an IPv6 address.

    .EXAMPLE
    Get-MyPublicIpAddress -ForceIPv4

    .OUTPUTS
    Your IPv4 or IPv6 address as a string.
    #>
    param (
        [Switch]$ForceIPv4
    )

    if ($ForceIPv4) {
        (Invoke-WebRequest -Uri 'http://ipv4.icanhazip.com').Content.Trim()
    }
    else {
        (Invoke-WebRequest -Uri 'http://icanhazip.com').Content.Trim()
    }
}

function Sync-EdgeProfileShortcuts {
    [CmdletBinding()]
    param ()

    if (!$IsWindows) {
        return
    }

    $EdgeProfilesPath = 'HKCU:\Software\Microsoft\Edge\Profiles'
    if (!(Test-Path -LiteralPath $EdgeProfilesPath)) {
        return
    }

    try {
        $EdgeProfiles = @(Get-ChildItem -LiteralPath $EdgeProfilesPath -ErrorAction Stop |
            Where-Object PSChildName -NE 'Default' |
            Get-ItemProperty -ErrorAction Stop)
        $EdgeCommand = Get-Command msedge.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $EdgeExecutable = $EdgeCommand.Source
        if (!$EdgeExecutable) {
            foreach ($InstallRoot in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
                if ($InstallRoot) {
                    $Candidate = Join-Path -Path $InstallRoot -ChildPath 'Microsoft\Edge\Application\msedge.exe'
                    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
                        $EdgeExecutable = $Candidate
                        break
                    }
                }
            }
        }
        if (!$EdgeExecutable) {
            Write-Verbose 'Edge was not found. Skipping profile shortcuts.'
            return
        }

        $StartMenuPath = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs'
        if (!(Test-Path -LiteralPath $StartMenuPath)) {
            New-Item -ItemType Directory -Path $StartMenuPath -ErrorAction Stop | Out-Null
        }

        $Shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $ManagedPrefix = 'PowerShell-Profile:Edge:'
        $ExpectedShortcuts = @()

        foreach ($EdgeProfile in $EdgeProfiles) {
            $ProfileId = $EdgeProfile.PSChildName
            $ProfileName = $EdgeProfile.ShortcutName
            if (!$ProfileName) {
                $ProfileName = $EdgeProfile.name
            }
            if (!$ProfileName) {
                $ProfileName = $ProfileId
            }

            $SafeName = ($ProfileName -replace '[<>:"/\\|?*\x00-\x1F]', '_').Trim().TrimEnd('.')
            $ShortcutName = "Edge ($SafeName)"
            $Description = "$ManagedPrefix$ProfileId"
            $ShortcutPath = Join-Path -Path $StartMenuPath -ChildPath "$ShortcutName.lnk"
            $Suffix = 0

            while (Test-Path -LiteralPath $ShortcutPath) {
                $ExistingShortcut = $Shell.CreateShortcut($ShortcutPath)
                if ($ExistingShortcut.Description -eq $Description) {
                    break
                }
                $Suffix++
                $ShortcutPath = Join-Path -Path $StartMenuPath -ChildPath "$ShortcutName ($Suffix).lnk"
            }

            $Shortcut = $Shell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = $EdgeExecutable
            $Shortcut.Arguments = '--profile-directory="{0}"' -f $ProfileId
            $Shortcut.WorkingDirectory = Split-Path -Parent -Path $EdgeExecutable
            $Shortcut.IconLocation = "$EdgeExecutable,0"
            $Shortcut.Description = $Description
            $Shortcut.Save()
            $ExpectedShortcuts += $ShortcutPath
        }

        foreach ($ShortcutFile in (Get-ChildItem -LiteralPath $StartMenuPath -Filter '*.lnk' -File -ErrorAction Stop)) {
            if ($ShortcutFile.FullName -in $ExpectedShortcuts) {
                continue
            }
            $ExistingShortcut = $Shell.CreateShortcut($ShortcutFile.FullName)
            if ($ExistingShortcut.Description -like "$ManagedPrefix*") {
                Remove-Item -LiteralPath $ShortcutFile.FullName -ErrorAction Stop
            }
        }
    }
    catch {
        Write-Warning "Unable to synchronize Edge profile shortcuts: $_"
    }
}

if ($IsWindows) {
    Sync-EdgeProfileShortcuts
}

# -- Models.json Check -- #
$ModelsJsonPath = Join-Path -Path $ProfileDirectory -ChildPath 'models.json'
$ModelsConfig = $null
$ModelsConfigValid = $false

if (!(Test-Path -LiteralPath $ModelsJsonPath)) {
    Write-Warning "models.json not found in $ProfileDirectory. Please create it manually with 'instructModel' and 'reasoningModel' keys."
}
else {
    try {
        $ModelsConfig = Get-Content -Path $ModelsJsonPath | ConvertFrom-Json
        if ($ModelsConfig.PSObject.Properties.Name -contains 'instructModel' -and $ModelsConfig.PSObject.Properties.Name -contains 'reasoningModel') {
            $ModelsConfigValid = $true
        }
        else {
            Write-Warning "models.json is missing required keys: 'instructModel' and/or 'reasoningModel'. Please update the file."
        }
    }
    catch {
        Write-Warning "Failed to parse models.json. Please ensure it is valid JSON."
    }
}

if ($ModelsConfigValid) {
    # Start-AiQuery is only loaded if the models.json file is valid
    function Start-AiQuery {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Prompt,

            [Parameter(Mandatory = $false)]
            [switch]$Reasoning
        )

        begin {
            if ($Reasoning) {
                $Model = $ModelsConfig.reasoningModel
            }
            else {
                $Model = $ModelsConfig.instructModel
            }
        }

        process {
            foundry model run $Model --prompt $Prompt
        }

        end { Write-Verbose "Response completed by $Model" }
    }
}

# -- Module Version Checks -- #

# Gets all PowerShell Modules - excluding the sub-modules of Az
$InstalledModules = Get-InstalledModule | Where-Object Name -NotLike Az.* | Where-Object Name -NotLike Microsoft.Graph.*

foreach ($module in $InstalledModules) {
    # Before we check for the last updates we need to make sure that the module is registered in the Data.json file

    # Filter information from $JSONDate to the current module
    $ModuleFromDataFile = $JSONData.powershellModules | Where-Object Name -eq $module.Name

    # Registers the PowerShell module to the Data file if it was not found (it's $null)
    if (!($ModuleFromDataFile)) {
        # Module is not registered in the Data.json file

        # Default body of a module in the Data.json file
        $NewModuleBody = @{
            Name            = $module.Name
            LastUpdateCheck = $null
            LastUpdated     = $null
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
    }
    else {
        # An else is used here as we don't want to run the code below if it has just been checked because of the above if statement
        # If the module was last checked for an update more than the configured amount of days ago
        # If LastUpdateCheck -GT (LastUpdateCheck + moduleDefaultUpdateFrequency)
        if ((Get-Date) -gt ($JSONData.powershellModules | Where-Object Name -eq $module.Name).LastUpdateCheck.AddDays($JSONConfig.PowerShell.moduleDefaultUpdateFrequency)) {
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
        }
        else {
            Write-Host ("⏱️  $($module.Name) has recently been checked for updates.")
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
        if ((Receive-Job -Keep -Id $Job.Id) -or ($true)) {

            if ($JSONConfig.PowerShell.moduleAutoUpdate) {
                $CurrentModule = $job.Name.Replace("VersionChecker-", "")
                Write-Host ("⚡ Attempting to update module: " + $CurrentModule)
                Update-Module -Name $CurrentModule -Verbose

                # Set the LastUpdated to the current date
                # Get the contents of the file to ensure we have the latest version
                $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
                # Update the LastUpdateCheck
                ($JSONData.powershellModules | Where-Object Name -eq $CurrentModule).LastUpdated = Get-Date -AsUTC      # Set
                # Save the new array to the Data.json file
                Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
                # Get to ensure we have the latest version, after just writing to it
                $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get

                Uninstall-ObsoleteModule -ModuleName $CurrentModule -Verbose

            }
            else {
                Write-Host ("⚠️ Update available for module: " + $CurrentModule)
                Write-Host (" To update use: Update-Module -Name " + $CurrentModule + ". Alternatively, set moduleAutoUpdate to true in $($JSONConfigPath). Updating manually will not update the LastUpdated property in the profile data file.")
            }
        }
        Remove-Job -Name $Job.Name
    }
}

# -- Oh-My-Posh -- #
# If Oh-My-Posh has not previously been checked for updates
if ((!($JSONData.OhMyPosh.LastUpdateCheck))) {
    # Oh-My-Posh has not been previously updated

    $ompVersion = oh-my-posh version
    # If Oh-My-Posh is installed and due for an update check
    if (($null -ne $ompVersion) -and ($JSONData.OhMyPosh.LastUpdateCheck) -gt ($JSONData.OhMyPosh.LastUpdateCheck + $JSONConfig.OhMyPosh.updateFrequency)) {
        Write-Host ("⚡ Attempting to update Oh-My-Posh!")
        winget upgrade JanDeDobbeleer.OhMyPosh -s winget | Out-Null

        # Set the LastUpdateCheck to the current date
        # Get the contents of the file to ensure we have the latest version
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
        # Update the LastUpdateCheck
        $JSONData.OhMyPosh.LastUpdateCheck = Get-Date -AsUTC  # Set
        # Save the new array to the Data.json file
        Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
        # Get to ensure we have the latest version, after just writing to it
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get

        $ompVersionPostUpgrade = oh-my-posh version
        if ($ompVersion -ne $ompVersionPostUpgrade) {

            # Set the LastUpdated to the current date
            # Get the contents of the file to ensure we have the latest version
            $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
            # Update the LastUpdated
            $JSONData.OhMyPosh.LastUpdated = Get-Date -AsUTC  # Set
            # Save the new array to the Data.json file
            Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
            # Get to ensure we have the latest version, after just writing to it
            $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json

            Write-Host ("ℹ️ Oh-My-Posh updated from version ${ompVersion} to ${ompVersionPostUpgrade}!")
        }
        else {
            Write-Host ("ℹ️ Oh-My-Posh already up to date!")
        }
    }
    if ($null -eq $ompVersion) {
        Write-Host ("⚡ Installing Oh-My-Posh!")
        winget install JanDeDobbeleer.OhMyPosh -s winget | Out-Null

        # Set the LastUpdated and LastUpdateCheck to the current date
        # Get the contents of the file to ensure we have the latest version
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json                                        # Get
        # Update the LastUpdated
        $Now = Get-Date -AsUTC
        $JSONData.OhMyPosh.LastUpdated = $Now           # Set
        $JSONData.OhMyPosh.LastUpdateCheck = $Now       # Set
        Remove-Variable Now
        # Save the new array to the Data.json file
        Set-Content -Path $JSONDataPath -Value ($JSONData | ConvertTo-Json)                                   # Save
        # Get to ensure we have the latest version, after just writing to it
        $JSONData = Get-Content -Path $JSONDataPath | ConvertFrom-Json
    }
}

# -- Module Imports -- #
Import-ModuleIfInstalled("Terminal-Icons")
Import-ModuleIfInstalled("Az.Accounts")         # Only a subnet of modules are imported to speed up startup
Import-ModuleIfInstalled("Az.Resources")
Import-ModuleIfInstalled("posh-git")
Import-ModuleIfInstalled("PSReadLine")

if ($null -ne (Get-Module -Name PSReadLine)) {
    # If PSReadLine is installed we set PSReadLineOptions

    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
}

Write-Host ("⚡ Starting Oh-My-Posh!")
oh-my-posh init pwsh --config (Join-Path -Path $ProfileDirectory -ChildPath 'Profile/bubbles-modified.json') | Invoke-Expression
if (Get-Module posh-git) {
    # Added this logic as setting this to true with now posh-git module installed causes a silent error and Oh-My-Posh to not load
    $env:POSH_GIT_ENABLED = $true
}
else { Write-Host ("❗ The PowerShell module posh-git is not installed. It's recommended to install it for the best experience.") }
# Uses Get-InstalledModule for AZ as we have not imported the whole module, unlike posh-git
if (Get-InstalledModule Az) {
    # Added this logic as setting this to true with now Az module installed causes a silent error and Oh-My-Posh to not load
    $env:POSH_AZURE_ENABLED = $true
}
else { Write-Host ("❗ The PowerShell module Az is not installed. It's recommended to install it for the best experience.") }
