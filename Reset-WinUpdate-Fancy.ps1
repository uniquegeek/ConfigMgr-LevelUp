#uniquegeek@gmail.com
# Stops windows update service and renames c:\SoftwareDistribution to .old
# Very similar to Microsoft script, but checks whether installers are running first
# Won't delete folder (can't) while installers are running.
# Helps fix corrupt windows updates / those signed with a cert we don't have anymore

$gpFolderTargetDays = 60 #delete GroupPolicy folder if older than these many days
$targetDate = Get-Date
#$targetDate = Get-Date -Day 1 -Month 1 -Year 2023  #or choose a specific date

#=========
if (-not(Test-Path C:\temp\Reset-WindowsUpdate.ps1)) {
    Copy-Item .\Reset-WindowsUpdate.ps1 -Destination "c:\temp" -force
}
$installerRunning = Get-Process | where {($_.name -eq "tiworker") -or ($_.name -eq "msiexec") -or ($_.name -eq "setup")}
if (-not($installerRunning)) {
    $today = Get-Date
    $SoftwarePath = 'C:\windows\SoftwareDistribution'
    $SoftwarePathNew = 'C:\windows\SoftwareDistribution.old'
    $Catroot2Path = 'C:\windows\System32\catroot2'
    $Catroot2PathNew = 'C:\windows\system32\catroot2.old'
    $gpFolder = "C:\windows\system32\GroupPolicy"
    $gpUserFolder = "C:\windows\system32\GroupPolicyUsers"
 
    $SoftwarePathDate = (Get-Item $SoftwarePath).LastWriteTime
    if (-not($SoftwarePathDate)) { $SoftwarePathDate = Get-Date -Year 2000 }

    #old zenworks user-side GPO gpedit.msc not needed and can interfere
    if (Test-Path $gpUserFolder) { Remove-Item $gpUserFolder -Force -Recurse }
    
    # stop services if running 
    #check if SoftwareDistribution is dead
    #may have been caused by a certificate issue with SCCM when we were troubleshooting patches in 2021
    if ((Test-Path $SoftwarePath) -and ($SoftwarePathDate -lt $targetDate)) { 
        if ((Get-Service wuauserv).Status -eq 'Running') { Stop-Service wuauserv -Force }
        if ((Get-Service CryptSvc).Status -eq 'Running') { Stop-Service CryptSvc -Force }
        if ((Get-Service BITS).Status -eq 'Running') { Stop-Service BITS -Force }
        if ((Get-Service msiserver).Status -eq 'Running') { Stop-Service msiserver -Force }
        Start-sleep 1
        if (Test-Path $SoftwarePathNew) { Remove-Item -Path $SoftwarePathNew -Recurse -Force }
        if (Test-Path $SoftwarePath) { Rename-Item -Path $SoftwarePath -NewName $SoftwarePathNew }
        if (Test-Path $Catroot2PathNew) { Remove-Item -Path $Catroot2PathNew -Recurse -Force }
        if (Test-Path $Catroot2Path) { Rename-Item -Path $Catroot2Path -NewName $Catroot2PathNew -force }
        #GroupPolicy folder can be fubar too
        #refresh if it's not modified somewhat recently
        if (Test-Path $gpFolder) {
            $gpFolderDate = (Get-Item $SoftwarePath).LastWriteTime
            if ($gpFolderDate) {
                if (($today - $gpFolderDate).Days -gt $gpFolderTargetDays) {
                    Remove-Item $gpFolder -Force -recurse
                    cmd.exe /c "GPUPDATE /force /target:user > NUL 2>&1"
                }
            }
        }
        #start services if they were previously running
        if ((Get-Service wuauserv).Status -ne 'Running') { Start-Service wuauserv }
        if ((Get-Service CryptSvc).Status -ne 'Running') { Start-Service CryptSvc }
        if ((Get-Service BITS).Status -ne 'Running') { Start-Service BITS }
        if ((Get-Service msiserver).Status -ne 'Running') { Start-Service msiserver }
    }
}


#====================================================================================
#if running manually, can check on state of gpfolders and softwaredistribution after:
$gpChecks = Get-Item C:\windows\System32\grouppolicy* -Force 
write-host "FilePath                         CreationTime           LastAccessTime" -ForegroundColor Gray
foreach ($gpCheck in $gpChecks) {  
    if ($gpCheck.CreationTime -ge $targetDate.AddDays(-90)) {[ConsoleColor]$gpCText = 'Green'}
    if ($gpCheck.CreationTime -lt $targetDate.AddDays(-90)) {[ConsoleColor]$gpCText = 'DarkYellow'}
    if ($gpCheck.CreationTime -lt $targetDate.AddDays(-180)) {[ConsoleColor]$gpCText = 'Red'}
    if ($gpCheck.LastAccessTime -ge $targetDate.AddDays(-90)) {[ConsoleColor]$gpAText = 'Green'}
    if ($gpCheck.LastAccessTime -lt $targetDate.AddDays(-90)) {[ConsoleColor]$gpAText = 'DarkYellow'}
    if ($gpCheck.LastAccessTime -lt $targetDate.AddDays(-180)) {[ConsoleColor]$gpAText = 'Red'}
    write-host $gpCheck.FullName -NoNewline
    write-host " " $gpCheck.CreationTime -ForegroundColor $gpCText -NoNewline 
    write-host " " $gpCheck.LastAccessTime -ForegroundColor $gpAText
}
if (-not($gpChecks)){
    write-host "No c:\Windows\system32\grouppolicy* folders"
}

$softChecks = Get-Item C:\windows\SoftwareDist* -Force 
foreach ($softCheck in $softChecks) {  
    if ($softCheck.CreationTime -ge $targetDate.AddDays(-90)) {[ConsoleColor]$gpCText = 'Green'}
    if ($softCheck.CreationTime -lt $targetDate.AddDays(-90)) {[ConsoleColor]$gpCText = 'DarkYellow'}
    if ($softCheck.CreationTime -lt $targetDate.AddDays(-180)) {[ConsoleColor]$gpCText = 'Red'}
    if ($softCheck.LastAccessTime -ge $targetDate.AddDays(-90)) {[ConsoleColor]$gpAText = 'Green'}
    if ($softCheck.LastAccessTime -lt $targetDate.AddDays(-90)) {[ConsoleColor]$gpAText = 'DarkYellow'}
    if ($softCheck.LastAccessTime -lt $targetDate.AddDays(-180)) {[ConsoleColor]$gpAText = 'Red'}
    write-host $softCheck.FullName -NoNewline
    write-host " " $softCheck.CreationTime -ForegroundColor $gpCText -NoNewline 
    write-host " " $softCheck.LastAccessTime -ForegroundColor $gpAText
}
if (-not($softChecks)){
    write-host "No c:\Windows\SoftwareDistribution* folders"
}

#if (Test-Path C:\windows\SoftwareDistribution.old) {
#    Remove-Item C:\windows\SoftwareDistribution.old -Recurse -Force
#} #won't work without permissions / ownership issues, ignore for now

if ($installerRunning) {
    write-host "Can't reset windows update folder while installers are running, try again later."
    $installerRunning
}
