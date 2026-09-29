$ProfilePath = Split-Path -Parent -Path $PROFILE

Copy-Item -Path Profile/Profile.ps1 -Destination $PROFILE -Recurse -Force
Copy-Item -Path Profile -Destination $ProfilePath -Recurse -Force
