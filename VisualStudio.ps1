# VS 2022
function vs2022 {
    # Import-Module 'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
    # Enter-VsDevShell 5d1c6581
    &'C:\Program Files\Microsoft Visual Studio\2022\*\Common7\Tools\Launch-VsDevShell.ps1' -Arch 'amd64' && cd -
}

