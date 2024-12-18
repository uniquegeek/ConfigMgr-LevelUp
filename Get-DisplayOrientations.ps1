#uniquegeek, 2024
#Found regkeys via ProcMon.exe while changing orientation in Windows.
#ProcMon is your fren
#Get display resolutions (X and Y values) using regkeys
#Count number of Portrait and Landscape displays
#Pure PowerShell, no .NET, C# needed
$h = hostname
$xRes = $yRes = $resolutions = $numPortrait = $numLandscape = 0
$currDisplays = "HKLM:\SYSTEM\CurrentControlSet\Control\UnitedVideo\CONTROL\VIDEO"
$xRes = "DefaultSettings.XResolution" #780 hex  = 1920 dec
$yRes = "DefaultSettings.YResolution" #438 hex = 1080 dec
$subkey = (Get-ChildItem $currDisplays).PSChildName
$dispID = $currDisplays + "\" + $subkey
$resolutions = Get-ChildItem -Path $dispID | Get-ItemProperty | Select $xRes,$yRes
$numPortrait = ($resolutions | where {$_.$xRes -lt $_.$yRes} | Measure-Object).count
$numLandscape = ($resolutions | where {$_.$yRes -lt $_.$xRes} | Measure-Object).count
#$numPortrait
#$numLandscape
$output = @($h,$subkey)
$resolutions | foreach {
    $output += $_.$xRes
    $output += $_.$yRes
    if ($_.$xRes -lt $_.$yRes) {
        $orient = "Portrait"
    } elseif ($_.$xRes -gt $_.$yRes) {
        $orient = "Landscape"
    } else {
        $orient = "nil"
    }
    $output += $orient
}
$output -join ","
