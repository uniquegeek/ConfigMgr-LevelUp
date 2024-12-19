#uniquegeek 20241219
#Copies a vertical and horizontal version of your org's wallpaper to a local dir (orgv.jpg, orgh.jpg)
#Then determines orientation of first connected display and copies appropriate version to org.jpg
#(use org.jpg in your GPO)

###Set these vars:
$orgName = "org"

#For new backgrounds: get the $hDate and $vDate, set in here
#(Get-Item .\scuh.jpg).LastWriteTime.ToShortDateString()
#(Get-Item .\scuv.jpg).LastWriteTime.ToShortDateString()
$hTargetDate = Get-Date -Month 12 -Day 3 -Year 2024 -Hour 0 -Minute 0 -Second 0 #12/3/2024 09:27, zero hour to ignore DST
$vTargetDate = Get-Date -Month 12 -Day 3 -Year 2024 -Hour 0 -Minute 0 -Second 0 #12/3/2024 09:27, zero hour to ignore DST

##################################################
############# Do Not edit below ##################
$horizontalWallDate = $verticalWallDate = $null
$wallH = $PSScriptRoot + "\" + $org + "h.jpg" #horizontal (landscape)
$wallV = $PSScriptRoot + "\" + $org + "v.jpg" #vertical (portrait)
$orgDir = "C:\" + $orgName
$orgWpDir = $orgDir + "\Wallpaper"
$orgWpH = $orgWpDir + "\" + $org + "h.jpg"
$orgWpV = $orgWpDir + "\" + $org + "v.jpg"
#e.x. C:\org\wallpaper\orgh.jpg
#e.x. C:\org\wallpaper\orgv.jpg

if (-not(Test-Path $orgDir -PathType Container)){New-Item -Path C:\ -Name $orgName -ItemType Directory -Force}
if (-not(Test-Path $orgWpDir -PathType Container)){New-Item -Path $orgDir -Name Wallpaper -ItemType Directory -Force}

if (Test-Path $orgWpH) {
    $horizontalWallDate = Get-Item $orgWpH -ErrorAction SilentlyContinue
}
if (Test-Path $orgWpV) {
    $verticalWallDate = Get-Item $orgWpV -ErrorAction SilentlyContinue
    #vertical for some ST tellers
}

if (-not($horizontalWallDate)){
    Copy-Item -Path $wallH -Destination $orgWpDir -Force -ErrorAction SilentlyContinue
} else {
    if ($horizontalWallDate.LastWriteTime -lt $hTargetDate) {
        Copy-Item -Path $wallH -Destination $orgWpDir -Force -ErrorAction SilentlyContinue
    }
}
if (-not($verticalWallDate)){
    Copy-Item -Path $wallV -Destination $orgWpDir -Force -ErrorAction SilentlyContinue
} else {
    if ($verticalWallDate.LastWriteTime -lt $vTargetDate) {
        Copy-Item -Path $wallV -Destination $orgWpDir -Force -ErrorAction SilentlyContinue
    }
}

######### Set-WallpaperOrientation ###############
#keep this in this script
#but also create a seperate Program with this to re-run daily or weekly
$localWp = $orgWpDir + "\" + $org + ".jpg" #used by gpo, set by this script

if ((Test-Path $orgWpH) -and (Test-Path $orgWpV)) {
    $currDisplay = (Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\UnitedVideo\CONTROL\VIDEO\{*}\0000" -ErrorAction SilentlyContinue | select Name).Name.Replace("HKEY_LOCAL_MACHINE","HKLM:")
    if ($currDisplay -is [array]) {$currDisplay = $currDisplay[0]}
    $xPixel = Get-ItemPropertyValue -Path $currDisplay -Name "DefaultSettings.XResolution" -ErrorAction SilentlyContinue
    $yPixel = Get-ItemPropertyValue -Path $currDisplay -Name "DefaultSettings.YResolution" -ErrorAction SilentlyContinue

    if (-not($currDisplay)) {
        #in case of error, assume default
        Copy-Item -Path $orgWpH -Destination $localWp -Force 
    }

    if ($xPixel -lt $yPixel){
        #if portrait/vertical
        if (-not(Test-Path $localWp)) {
            Copy-Item -Path $orgWpV -Destination $localWp -Force 
        } else {
            #if file size of Vertical and default not the same, make the Vertical one default
            if ((Get-Item $orgWpV).Length -ne (Get-Item $localWp).Length) {
                Copy-Item -Path $orgWpV -Destination $localWp -Force 
            }
        }
    } else {
        #if landscape/horizontal or nil
        if (-not(Test-Path $localWp)) {
            Copy-Item -Path $orgWpH -Destination $localWp -Force 
        } else {
            if ((Get-Item $orgWpH).Length -ne (Get-Item $localWp).Length) {
                Copy-Item -Path $orgWpH -Destination $localWp -Force 
            }
        }
    }
}
