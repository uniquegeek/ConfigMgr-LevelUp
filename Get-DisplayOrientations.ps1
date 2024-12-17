#uniquegeek, 2024
#Found regkeys via ProcMon.exe while changing orientation in Windows.
#ProcMon is your fren
#Get display resolutions (X and Y values) using regkeys
#Count number of Portrait and Landscape displays
#Pure PowerShell, no . N E T, C # needed
$xRes = $yRes = $resolutions = $numPortrait = $numLandscape = 0
$currDisplays = "HKLM:\SYSTEM\CurrentControlSet\Control\UnitedVideo\CONTROL\VIDEO"
$xRes = "DefaultSettings.XResolution" #780 hex  = 1920 dec
$yRes = "DefaultSettings.YResolution" #438 hex = 1080 dec
$dispID = $currDisplays + "\" + (Get-ChildItem $currDisplays).PSChildName
$resolutions = Get-ChildItem -Path $dispID | Get-ItemProperty | Select $xRes,$yRes
#$resolutions #if you want to see the actual values
#$resolutions[0] #to get first display only
$numPortrait = ($resolutions | where {$_.$xRes -lt $_.$yRes} | Measure-Object).count
$numLandscape = ($resolutions | where {$_.$yRes -lt $_.$xRes} | Measure-Object).count
#$numPortrait
#$numLandscape
