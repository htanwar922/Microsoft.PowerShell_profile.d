################### Add this block in the $PROFILE file ###################
# # Load all profile scripts in the Microsoft.PowerShell_profile.d directory
# $thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# $profileDir = "$thisDir\Microsoft.PowerShell_profile.d"
# if (Test-Path $profileDir) {
#     Get-ChildItem -Path $profileDir -Filter *.ps1 -Recurse | Sort-Object BaseName | ForEach-Object { . $_.FullName }
# }

# # Autocomplete
# Import-Module PSReadLine
# Set-PSReadLineOption -PredictionSource History
Set-PSReadLineKeyHandler -Chord "Ctrl+RightArrow" -Function ForwardWord
