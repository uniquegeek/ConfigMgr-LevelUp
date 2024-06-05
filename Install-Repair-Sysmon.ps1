#uniquegeek 20240604
#This script automatically repairs and installs sysmon with a config of your choosing.
#  If sysmon is baked, it needs to be uninstalled in two parts with a reboot in between.
#  Then you can install sysmon properly.
#This script handles that scenario.

#=== set your config file target date here ===
#                         yyyymmdd
[int]$configTargetDate = "20190522"

#=========================================
#=========================================
### Do not edit below ###
#=========================================
#=========================================
	$stageDir = "C:\temp\sysconfig"
	$stagedExe = "C:\temp\sysconfig\sysmon64.exe"
	$stagedConfig = "C:\temp\sysconfig\sysconfig.xml"
	$targetConfig = "\temp\sysconfig\sysconfig.xml"
	$targetConfigType = "\temp\sysconfig*"
	#if you want to change \temp\ to something else,
	#find this line below and change it too:
	#  cmd /c "C:\temp\sysconfig\sysmon64.exe" -i "C:\temp\sysconfig\sysconfig.xml" -accepteula 

#get install status first
#======== sysmon ==========
$sysDateComp = "0"
$sysPath = "none"
$sysSvcExist = "none"
$sysState = "none"
$sysState = "none"
$sysStart = "none"
$sysSvcConfigFile = "none"
$sysEventRegkey = "none"
if (Test-Path "C:\windows\Sysmon64.exe") {
    $sysPath = "C:\windows\Sysmon64.exe"
    $currSysConfig = cmd /c  C:\windows\Sysmon64.exe -c '2>&1' #throws error but grabs config as strings anyway
    $sysSvcConfigFile = $currSysConfig[11].split(':')[-1]
}
$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
if ($CurrSysmonSvc -ne $null) {
    $sysSvcExist = "sysmon64 service"
    $sysState = $CurrSysmonSvc.State
    $sysStart = $CurrSysmonSvc.StartMode
}
if (Test-Path $stagedConfig) {  #our .xml
    [int]$sysDateComp = (((Get-Item $stagedConfig).LastWriteTime).GetDateTimeFormats()[5]).Replace("-","")
}  
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\EventLog-Microsoft-Windows-Sysmon-Operational") {
	$sysEventRegkey = "yes" ######
}

##============ if you want to get states, for testing: =================
#$output = @($sysPath,$sysSvcExist,$sysState,$sysStart,$sysSvcConfigFile,$sysDateComp,$sysEventRegkey)
#write-host '$sysPath,$sysSvcExist,$sysState,$sysStart,$sysSvcConfigFile,$sysDateComp,$sysEventRegkey'
#$output = $output -join ","
#write-host $output

if (($sysPath -eq 'C:\windows\Sysmon64.exe') -and ($sysState -ne "none") -and ($sysSvcConfigFile -ne $targetConfig)) {
	$continueInstallFix = $true
}
#sysState becomes none AFTER this script runs, that is a task for uninstall-part2
if ($continueInstallFix){
	#==========================================
	#Installs sysmon if not installed, updates config if needed.
	#MS SysInternals installs sysmon in:
	#  "C:\Windows\Sysmon64.exe" 
	#sysmon64.exe and sysmondrv.sys both get installed in c:\windows after install (-i)

	#=== Drop current sysmon64.exe in staging area
	$sysDateComp = "0"
	if (Test-Path $stagedConfig) {
		[int]$sysDateComp = (((Get-Item $stagedConfig).LastWriteTime).GetDateTimeFormats()[5]).Replace("-","")
	} else {
		if (-not(Test-Path $stageDir)) { New-Item -ItemType Directory -Path $stageDir }
		Copy-Item "sysconfig.xml" -Destination $stageDir -Force
	}
	if ($sysTargetDate -gt $sysDateComp) {
		Copy-Item "sysconfig.xml" -Destination $stageDir -Force 
	}
	if (-not(Test-Path $stagedExe)) {
		Copy-Item "sysmon64.exe" -Destination $stageDir -Force
	}
	#=== BORKED SYSMON FIX PART 1
	#Using hints from https://www.jamesgibbins.com/posts/sysmon-install/ : 
	#  The executable is there, but the service relating to it doesn’t exist. Yet the driver is still up and running.
	#     If you try to stop the driver manually after a failed -u uninstall, it often doesn’t 
	#     - you get a Stopping the service failed error, or it just hangs at Stopping.
	#  There is a solution, however. If the registry keys relating to the service don’t exist, then,
	#     on the next reboot, the service doesn’t exist either. Hence, it doesn’t start (and therefore doesn’t need stopping),
	#     so you can delete SysmonSys.Drv and you’re good to go!
	$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
	if ($CurrSysmonSvc -ne $null) {
		$CurrSysmonSvcState = $CurrSysmonSvc.State
		if ($CurrSysmonSvcState -eq "Stopped") {
			#Uninstall sysmon if it exists
			Start-Sleep 1
			if (Test-Path "C:\Windows\sysmon64.exe") {
				Start-Process "C:\Windows\sysmon64.exe" -ArgumentList "-u" -NoNewWindow -Wait
			} else {
				Start-Process $stagedExe -ArgumentList "-u" -NoNewWindow -Wait
			}
		}
		$items = @(
			"HKLM:\SYSTEM\CurrentControlSet\Services\Sysmon64",
			"HKLM:\SYSTEM\CurrentControlSet\Services\SysmonDrv",
			"HKLM:\SYSTEM\ControlSet001\Services\Sysmon64",
			"HKLM:\SYSTEM\ControlSet001\Services\SysmonDrv",
			"HKLM:\SYSTEM\ControlSet002\Services\Sysmon64",
			"HKLM:\SYSTEM\ControlSet002\Services\SysmonDrv",
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Sysmon/Operational",
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{5770385f-c22a-43e0-bf4c-06f5698ffbd9}",
			"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\EventLog-Microsoft-Windows-Sysmon-Operational"
		)
		foreach ( $i in $items ) {
			Remove-Item -Path $i -Force -Recurse -ErrorAction SilentlyContinue
		}
	}
}

#Note a reboot is needed here (or after part 2?) before sysmon can install properly.
#A) You can split this script up with a task sequence and countdown if you want to be aggressive about it
#B) Or, you can let it partially fix, the app will fail, but after the next time the device restarts
#   and tries this installer again, it will do the rest of the fix and report as successful.

#=== BORKED SYSMON FIX PART 2
$sysDateComp = "0"
$sysPath = "none"
$sysSvcExist = "none"
$sysStart = "none"
$sysSvcConfigFile = "none"
if (Test-Path "C:\windows\Sysmon64.exe") {
    $sysPath = "C:\windows\Sysmon64.exe"
    $currSysConfig = cmd /c  C:\windows\Sysmon64.exe -c '2>&1' #throws error but grabs config as strings anyway
    $sysSvcConfigFile = $currSysConfig[11].split(':')[-1]
}
$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
if ($CurrSysmonSvc -ne $null) {
    $sysSvcExist = "sysmon64 service"
    $sysStart = $CurrSysmonSvc.StartMode
}
if (($sysSvcExist -ne "none") -and ($sysStart -eq "none") -and ($sysSvcConfigFile -eq "none")) {
    #=== BORKED SYSMON FIX 
    #Then, after a reboot, you can delete C:\Windows\SysmonDrv.sys (and C:\Windows\Sysmon64.exe if you haven’t already).
    #maybe don't need a reboot??? testing that here
    if (Test-Path "C:\Windows\SysmonDrv.sys") {
        Remove-Item "C:\Windows\SysmonDrv.sys" -Force
    }
    if (Test-Path "C:\Windows\Sysmon64.exe") {
        Remove-Item "C:\Windows\Sysmon64.exe" -Force
    }
    #=== BORKED SYSMON FIX 
}

###############################
# now actually install sysmon!
###############################
#This section installs sysmon if not installed, updates config if needed.
#MS SysInternals installs sysmon in:
#  "C:\Windows\Sysmon64.exe" 
#	sysmon64.exe and sysmondrv.sys both get installed in c:\windows after install (-i)

#SYSMON install conditions
#these must all be missing in order to install
$continueInstall = $false
$sysPath = $sysSvcExist = $sysState = $sysStart = $sysSvcConfigFile = $sysEventRegkey = "missing"
if (Test-Path "C:\windows\Sysmon64.exe") {  
    $sysPath = "C:\windows\Sysmon64.exe"
    $currSysConfig = cmd /c  C:\windows\Sysmon64.exe -c '2>&1' #throws error but grabs config as strings anyway
    $sysSvcConfigFile = $currSysConfig[11].split(':')[-1]
}
$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
if ($CurrSysmonSvc -ne $null) {
    $sysSvcExist = "sysmon64 service"
    $sysState = $CurrSysmonSvc.State
    $sysStart = $CurrSysmonSvc.StartMode
}
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\EventLog-Microsoft-Windows-Sysmon-Operational") {
	$sysEventRegkey = "yes" ######
}
if (($sysPath -eq "missing") -and ($sysSvcExist -eq "missing") -and ($sysState -eq "missing") -and ($sysStart -eq "missing") -and ($sysSvcConfigFile -eq "missing") -and ($sysEventRegkey -eq "missing")) {
	$continueInstall = $true
}
#can't attempt install at all until all these conditions are true;
if ($continueInstall) {
	$reloadSysConfig = $false
	$sysDateComp = "0"
	#stage config file
	if (Test-Path $stagedConfig) {
		[int]$sysDateComp = (((Get-Item $stagedConfig).LastWriteTime).GetDateTimeFormats()[5]).Replace("-","")
	} else {
		if (-not(Test-Path $stageDir)) { New-Item -ItemType Directory -Path $stageDir }
		Copy-Item "sysconfig.xml" -Destination $stageDir -Force
		$reloadSysConfig = $true
	}
	if ($sysTargetDate -gt $sysDateComp) {
		Copy-Item "sysconfig.xml" -Destination $stageDir -Force 
		$reloadSysConfig = $true
	}
    #=== Drop current sysmon64.exe in staging area
	if (-not(Test-Path $stagedExe)) {
		Copy-Item "sysmon64.exe" -Destination $stageDir -Force
	}
	#=== Install sysmon64 and config if it doesn't exist
	if (-not(Test-Path "C:\Windows\sysmon64.exe")) {
		cmd /c "C:\temp\sysconfig\sysmon64.exe" -i "C:\temp\sysconfig\sysconfig.xml" -accepteula 
		$reloadSysConfig = $false  #already updated because we just installed it
	}
	#=== Check if we need to reload sysmon64 config
	#verify sysmon installed now
	Start-Sleep 1
	$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
	if ($CurrSysmonSvc -ne $null) {
		#-c prints current config file in use
		$currSysConfig = cmd /c  C:\windows\Sysmon64.exe -c '2>&1' #throws error but grabs config as strings anyway
		$currSysConfigFile = $currSysConfig[11].split(':')[-1]
		if ($currSysConfigFile -notlike $targetConfigType) {
			$reloadSysConfig = $true
		}
		#if we have a new config or the current one needs updating, reload sysconfig xml
		if ($reloadSysConfig) {
			#& "C:\Windows\sysmon64.exe" -c "C:\temp\sysconfig\sysconfig.xml"
			$configArgs = @("-c",$stagedConfig)
			Start-Process "C:\Windows\sysmon64.exe" -ArgumentList $configArgs -NoNewWindow -Wait
			Restart-Service sysmon64 -Force | Out-Null
		}
	}
}
