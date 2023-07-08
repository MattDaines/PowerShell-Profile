# PowerShell Profile

## Goals

- 🎯 Standardise all of my consoles. There's a focus on Azure administration, as that's what I do!

## Things to Improve

- 💫 Add a persistent storage config file to prevent checking for PowerShell module updates every time a new session is opened.
- 💫 Create my own Oh-My-Posh profile
- 💫 A script to automatically `git pull` and copy any updates to the profiles

## How To Use

- 1️⃣ Clone the repository
- 2️⃣ In a PowerShell console, navigate to the root of the cloned repository
- 3️⃣ Run `Import-Profile.ps1`

## Troubleshooting

### VS Code Terminal Is Not Rendering Foreground Text Correctly

[Stak Overflow Reference](https://stackoverflow.com/questions/71890831/rendering-strange-in-vscode-terminal-with-oh-my-posh-v3)

1) Open VS Code Settings via Ctrl+,
2) Search for the item "Terminal > Integrated: Minimum Contrast Ratio"
3) Set the value to 1 (from 4.5)