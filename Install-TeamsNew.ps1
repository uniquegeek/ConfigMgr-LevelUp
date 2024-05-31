#Set what version of New Teams are we installing. (~20240531)
#Get version by installing once then using "Get-AppxPackage -AllUsers MSTeams | fl *"
[system.version]$installerVer = "24074.2321.2810.3500"

#========================================
#this script has more control than
#.\teamsbootstrapper.exe -p -o ."\\cmserver\Sources\Applications\Microsoft\Teams\20231208msix\appxBootstrapper\MSTeams-x64.msix"
$upgradeMe = $false
$p = Get-AppxProvisionedPackage -Online | where {$_.DisplayName -eq "msteams"}
if ($p) {
    [system.version]$pcNewestVer = ($p | Sort-Object -Descending -Property version | Select-Object -First 1).version
    if ($installerVer -gt $pcNewestVer) {
        $upgradeMe = $true
    }
}
if (($upgradeMe -eq $true) -or ($p -eq $null)) {
    if (-not(Test-Path "C:\OurOrg\Teams")) {
        New-Item -Path "C:\OurOrg" -Name "Teams" -ItemType Directory -Force
    }
    Copy-Item "MSTeams-x64.msix" -Destination "C:\OurOrg\Teams" -Force
    Copy-Item "teamsbootstrapper.exe" -Destination "C:\OurOrg\Teams" -Force
    $a = @(
        ,"-p"
        ,"-o"
        ,"c:\OurOrg\Teams\MSTeams-x64.msix"
    )
    #kill running Teams processes first
    Get-Process Teams | Stop-Process -ErrorAction SilentlyContinue -force | Out-Null
    Get-Process ms-teams | Stop-Process -ErrorAction SilentlyContinue -force | Out-Null

    #c:\temp\teamsbootstrapper.exe -p -o "c:\temp\MSTeams-x64.msix"
    Start-Process "c:\OurOrg\teams\teamsbootstrapper.exe" -ArgumentList $a -NoNewWindow -Wait
}

#========== Install new desktop icon except on IT computers ================
#(as of May 31, MS might have renamed it to Microsoft Teams.lnk now?)
#note "Microsoft Teams (work or school).lnk" appears in the windows all apps menu,
#but I could not find it in the usual Start Menu folder in ProgramFiles, or the user's StartMenu folder
#new appx installer doing new funky stuff
#I had to drag the app from All Apps to desktop, which created a shortcut (could not find source with procmon)
#Then I zipped it because sometimes copying .lnk can be flaky and put it with this installer
#Icon will get unzipped to public desktop when new Teams installs
$excludePCs = @(
    "comp1", #johndoe pc
    "comp2" #janedoe pc 
)
$p = Get-AppxPackage -AllUsers -name MSTeams
if ($p) {
    $h = hostname
    if ($h -notin $excludePCs) {
        #Copy-Item "Microsoft Teams (work or school).lnk" -Destination "C:\Users\Public\Desktop" -Force
        #note: .lnk can act funny sometimes when referencing, that's why I put it in a zip
        Copy-Item "PublicIcon.zip" -Destination "C:\OurOrg\Teams" -Force
        Expand-Archive "C:\OurOrg\Teams\PublicIcon.zip" -DestinationPath "C:\Users\Public\Desktop" -Force
    }
    #remove old icon "Microsoft Teams.lnk" 
    #  (new is "Microsoft Teams (work or school).lnk", keep that)
    $oldLinks = Get-ChildItem -Path "C:\users" -Filter "Microsoft Teams.lnk" -Recurse
    foreach ($link in $oldLinks) {
        Remove-Item $link.Fullname -Force -ErrorAction SilentlyContinue
    }
} 
#==================================================
#del msix and dumped installer files if installed
#the msix is 125MB, doesn't need to be there
$p = Get-AppxProvisionedPackage -Online | where {$_.DisplayName -eq "msteams"}
if ($p) {
    [system.version]$pcNewestVer = ($p | Sort-Object -Descending -Property version | Select-Object -First 1).version
    if ($pcNewestVer -eq $installerVer) {
        Remove-Item "C:\OurOrg\Teams\MSTeams-x64.msix" -Force
        Remove-Item "C:\OurOrg\Teams\teamsbootstrapper.exe" -Force
        Remove-Item "C:\OurOrg\Teams\PublicIcon.zip" -Force
    }
}
#==========================================
# Uninstall Teams Machine-Wide
if ($p) {
    $u = $null
    $u = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Teams Machine-Wide Installer" } | get-itempropertyvalue -name UninstallString
    #if uninstall key exists
    if ($u) {
    #get GUID part only:
        $g = $u.SubString(14)
        $m="/qn /promptrestart /x"
        $a = $m + $g
        Get-Process Teams | Stop-Process -ErrorAction SilentlyContinue -force | Out-Null
        start-process -filepath "$env:systemroot\system32\msiexec.exe" -argumentlist $a -windowstyle hidden -wait
    }
    #Uninstalling MW does sort of does the uninstalls in user profiles as well
    #User uninstall leaves two files: .dead and Update.exe in c:\Users\username\AppData\Local\Microsoft\Teams\
    $userFolders = Get-ChildItem C:\Users\
    foreach ($f in $userFolders) {
        try {
            if (test-path "$($f.fullname)\AppData\Local\Microsoft\Teams\Update.exe"){
                Start-Process "$($f.fullname)\AppData\Local\Microsoft\Teams\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait | Out-Null
            }
        } catch {
        Write-Output "Uninstall failed with exception $_.exception.message"
        exit /b 1
        }
    }
    #Teams GPO removes regkey value the msi uninstall generates
    #HKCU:\software\microsoft\office\teams PreventInstallationFromMSI REG_DWORD 1
    #Can't run as current user in this script, so use gpupdate
    #Might not be needed once new Teams is installed, commenting out for now
    #gpupdate /force
    
    
#### USE FOR DETECTION SCRIPT ###
##This program is completely installed if these four criteria are met:
##1) device has Teams New that is this installer's version or higher:
#[system.version]$targetVer = "24074.2321.2810.3500"
#$p = Get-AppxProvisionedPackage -Online | where {$_.DisplayName -eq "msteams"}
#if ($p) { [system.version]$pcNewestVer = ($p | Sort-Object -Descending -Property version | Select-Object -First 1).version }
##2) The desktop has the new shortcut "Microsoft Teams (work or school).lnk"
#$newShortcut = Test-Path "c:\users\public\Desktop\Microsoft Teams (work or school).lnk"
#$excludePCs = @("comp1","comp2")
#$h = hostname
#if ($h -in $excludePCs) { $newShortcut = $true }
##3) The old desktop shortcuts are gone
#$oldLinksGone = (((Get-ChildItem -Path "C:\users" -Filter "Microsoft Teams.lnk" -Recurse | Measure-Object).Count) -eq 0)
##4) Teams Machine-Wide is uninstalled
#$TeamsMWGone = (-not(Test-Path "C:\Program Files (x86)\Teams Installer\Teams.exe"))
#======================
#if (($pcNewestVer -ge $targetVer) -and $newShortcut -and $oldLinksGone -and $TeamsMWGone ) {
#    write-host "This version or newer installed, cleanup done"
#}
##If these four criteria are not met, we "install Teams New"
##The Teams New installer script also checks and remediates all these requirements.
