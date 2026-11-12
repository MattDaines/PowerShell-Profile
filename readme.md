# PowerShell Profile

## Goals

- 🎯 Standardise all of my PowerShell consoles. There's a heavy focus on Azure administration, as that's mostly what I do!

## Things to Improve

- ~~💫 Add a persistent storage config file to prevent checking for PowerShell module updates every time a new session is opened.~~ ✅ **Done!**
- ~~💫 Create my own Oh-My-Posh profile~~ ✅ **Done!**
- ~~💫 A script to automatically `git pull` this repository and import any updates to the profiles~~ ✅ **Done!**

## How To Use

### Install Dependencies

The terminal uses [Oh-My-Posh](https://ohmyposh.dev/) to jazz up the terminal. To install it:

- Install [Oh My Posh](https://ohmyposh.dev/docs/installation/windows) by running `winget install JanDeDobbeleer.OhMyPosh -s winget`
- Restart your terminal to update `PATH`, and run: `oh-my-posh version`. If Oh My Posh cannot be found then restart your device and try again.

We'll also want to install the PowerShell modules that are automatically imported into the profile.

```powershell
Install-Module Az, Terminal-Icons, posh-git, PSReadLine
```

### Install Fonts

The theme that I use uses glyphs which requires a Nerd Font to be installed. You can install a Nerd Font by running `oh-my-posh font install --user`.

Personally, I like `CascadiaCode`.

We now need to configure our applications to use the fonts.

For **Windows Terminal** you'll want to insert the below into your desired profiles:

```json
"font": {
  "face": "CaskaydiaCove NFM"
}
```

**Or** you cna just use the appearance settings in the Windows Terminal settings.

For **VS Code** you will need to update the setting `terminal.integrated.fontFamily` to: `CaskaydiaCove Nerd Font Mono`. You can also provide a list: `'CaskaydiaCove Nerd Font Mono', Consolas, 'Courier New', monospace`.

> **Missing Glyphs?**
>
> If the glyphs are not showing up, try restarting VS Code!

### Import The Profile

Now that we have the PowerShell modules and fonts installed we can import the profile:

- Clone the repository: `git clone https://github.com/MattDaines/PowerShell-Profile`
- In a PowerShell console, navigate to the root of the cloned repository
  - Running `ls` or `Get-ChildIdem` should show the `Import-Profile.ps1` file as well as the `Profile` directory
- Run `.\Import-Profile.ps1` which copies the files to your `$PROFILE` directory.

On Linux, run the importer with `./Import-Profile.ps1` in PowerShell. The profile uses `~/Documents/Repos` as its default starting directory on Linux (and the equivalent path under your home directory on Windows).

> Import
>
> You will need to run `.\Import-Profile.ps1` from both Windows Terminal/PowerShell 7 and the integrated terminal in VS Code. The two applications use a different `$PROFILE` path.
> - VS Code: `"$ENV:USERPROFILE\Documents\PowerShell\Microsoft.VSCode_profile.ps1"`
> - Terminal: `"$ENV:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"`

## Automatic Profile Updates

Run `./Import-Profile.ps1` once from your clone for each PowerShell host to enable automatic updates. The importer can also be invoked by its full path from another directory. It records the clone's absolute path in `PowerShell.repositoryPath` in `config.json` beside `$PROFILE`, preserving existing settings.

Each profile invocation checks the clone for local changes, switches a clean clone to `main`, and runs `git pull --ff-only origin main`. Git runs without interactive authentication and has a total update timeout of 15 seconds. Routine updates are silent. When the commit differs from the installed version, the importer copies the files and the updated profile loads in the same session.

Local edits, divergent history, unavailable Git, and connection failures produce a warning and allow the installed profile to continue loading. Commit or stash local edits, resolve divergence manually, or restore connectivity, then invoke the profile again. If you move the clone, run its importer again to refresh the configured path.

Successful installations are recorded per host profile in `data.json`. An interrupted import is retried on the next successful update check. You can also run the importer manually to reinstall the files.

## Configuration Schema

`config.schema.json` defines the profile configuration fields and WinGet rules. Running `.\Import-Profile.ps1` copies it beside `$PROFILE`. The profile adds `"$schema": "./config.schema.json"` to new and existing `config.json` files so editors that support JSON Schema can offer completion and validation. An existing `$schema` setting is preserved.

## WinGet Updates

On Windows, run `Start-WinGetUpdate` when you are ready to update available packages.
Use `Start-WinGetUpdate -WhatIf` to preview the operations. Each invocation refreshes the available updates and reads `config.json` beside `$PROFILE`.

Packages default to upgrading by their exact ID. Add rules to the `WinGet.packages` array in `config.json` to change this behavior.

```json
"WinGet": {
  "packages": [
    {
      "id": "Vendor.*",
      "updateStrategy": "upgrade",
      "referenceBy": "name"
    },
    {
      "id": "Vendor.SpecificPackage",
      "updateStrategy": "reinstall",
      "referenceBy": "name"
    }
  ]
}
```

`id` supports case-insensitive PowerShell wildcards. An exact ID rule wins over wildcard rules, otherwise the first matching wildcard rule in JSON order wins. `updateStrategy` accepts `upgrade`, `reinstall`, or `skip` and defaults to `upgrade`.
Use `skip` to exclude matching packages from the update run, for example `{ "id": "Vendor.*", "updateStrategy": "skip" }`.
`referenceBy` accepts `name` or `id` and defaults to `id`. Names and IDs come from the parsed WinGet package objects.

Reinstall runs a separate uninstall followed by install, using the same name or ID for both. If uninstall fails, the package is skipped. Other packages continue after a failure, and normal installer prompts remain available. Rows with unusable IDs are skipped, as are name-based operations whose displayed name is truncated.

After updating this repository, run `.\Import-Profile.ps1` and open a new PowerShell session to load the function.

## Troubleshooting

### VS Code Terminal Is Not Rendering Foreground Text Correctly

[Stack Overflow Reference](https://stackoverflow.com/questions/71890831/rendering-strange-in-vscode-terminal-with-oh-my-posh-v3)

1) Open VS Code Settings via `Ctrl + ,`
2) Search for the item "Terminal > Integrated: Minimum Contrast Ratio"
3) Set the value to 1 (from 4.5)
