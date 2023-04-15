$ProfilePath = $PROFILE
$ProfilePath = $ProfilePath.Substring(0, $ProfilePath.LastIndexOf("\"))
$ProfilePath

Copy-Item -Path Profile/Profile.ps1 -Destination $PROFILE -Recurse -Force
Copy-Item -Path Profile -Destination $ProfilePath -Recurse -Force
