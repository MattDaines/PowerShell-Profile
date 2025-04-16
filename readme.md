# PowerShell Profile

## Goals

- 🎯 Standardise all of my PowerShell consoles. There's a heavy focus on Azure administration, as that's mostly what I do!

## Things to Improve

- ~~💫 Add a persistent storage config file to prevent checking for PowerShell module updates every time a new session is opened.~~ ✅ **Done!**
- ~~💫 Create my own Oh-My-Posh profile~~ ✅ **Done!**
- 💫 A script to automatically `git pull` this repository and import any updates to the profiles

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

> Import 
>
> You will need to run `.\Import-Profile.ps1` from both Windows Terminal/PowerShell 7 and the integrated terminal in VS Code. The two applications use a different `$PROFILE` path.
> - VS Code: `"$ENV:USERPROFILE\Documents\PowerShell\Microsoft.VSCode_profile.ps1"`
> - Terminal: `"$ENV:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"`

## Troubleshooting

### VS Code Terminal Is Not Rendering Foreground Text Correctly

[Stack Overflow Reference](https://stackoverflow.com/questions/71890831/rendering-strange-in-vscode-terminal-with-oh-my-posh-v3)

1) Open VS Code Settings via `Ctrl + ,`
2) Search for the item "Terminal > Integrated: Minimum Contrast Ratio"
3) Set the value to 1 (from 4.5)
