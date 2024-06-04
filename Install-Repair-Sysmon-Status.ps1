#uniquegeek 20240604
#Use in ConfigMgr (SCCM)'s "Software Library \ Scripts" to query current configs and states

$h = hostname
$LoggedInUser = (Get-WmiObject -class win32_computersystem).username
if ($LoggedInUser -eq $null) { $LoggedInUser = "noUser" } else { $LoggedInUser = Split-Path $LoggedInUser -leaf }

#======== sysmon ==========
$sysDateComp = "0"
$sysPath = "no sysExe"
$sysSvcExist = "no sysSvc"
$sysState = "no sysState"
$sysStart = "no sysStart"
$sysSvcConfigFile = "no sysConfigSet"
$sysDateComp = "no sysConfigStage"

#sysmon is installed if:
#  c:\windows\sysmon64.exe exists
#  sysmon64 service exists
#  sysmon64 uses sysconfig.xml with proper path
#  c:\temp\sysconfig\sysmonconfig.xml is target date

#$sysPathYes
if (Test-Path "C:\windows\Sysmon64.exe") {
    $sysPath = "C:\windows\Sysmon64.exe"
    $currSysConfig = cmd /c  C:\windows\Sysmon64.exe -c '2>&1' #throws error but grabs config as strings anyway
    $sysSvcConfigFile = $currSysConfig[11].split(':')[-1]
}
#$sysSvcExist
#$sysSvcConfigFile
$CurrSysmonSvc = Get-WmiObject win32_service | where {$_.name -eq 'sysmon64'}
if ($CurrSysmonSvc -ne $null) {
    $sysSvcExist = "sysmon64 service"
    $sysState = $CurrSysmonSvc.State
    $sysStart = $CurrSysmonSvc.StartMode
}
#sysDateComp
if (Test-Path "C:\temp\sysconfig\sysconfig.xml") {
    [int]$sysDateComp = (((Get-Item "C:\temp\sysconfig\sysconfig.xml").LastWriteTime).GetDateTimeFormats()[5]).Replace("-","")
}  

#========= elastic =========
$elasticAgent = "no elasticSvc"
$elasticState = "no elasticState"
$elasticStart = "no elasticStart"
$wlbSvc = "no wlbSvc"
$wlbState = "no wlbState"
$wlbStart = "no wlbStart"
$wlbSvcPath = "no wlbSvcPath"
$oldWlbFiles = "no oldWlbFiles"
$pmpWlbFiles = "no PMPWlbFiles"

#report new elastic winlogbeat-ish service specs
$e = Get-WmiObject win32_service | where {($_.name -eq 'Elastic Agent')}
if ($e) {
    $elasticAgent = "Elastic Agent"
    $elasticState = $e.State
    $elasticStart = $e.StartMode
}

#report old elastic winlogbeat service specs
$w = Get-WmiObject win32_service | where {($_.name -eq 'winlogbeat')}
if ($w) {
    $wlbSvc = "winlogbeat service"
    $wlbState = $w.State
    $wlbStart = $w.StartMode
    if ($CurrWlbSvc.pathname -like "`"C:\ProgramData\Elastic\Beats\winlogbeat\winlogbeat.yml") {
        $wlbSvcPath = "C:\ProgramData\Elastic\Beats"
    }
}

#=============================
$output = @(
    $h,
    $LoggedInUser,
    $sysPath,
    $sysSvcExist,
    $sysState,
    $sysStart,
    $sysSvcConfigFile,
    $sysDateComp,
    $elasticAgent,
    $elasticStart,
    $elasticState,
    $wlbSvc,
    $wlbState,
    $wlbStart,
    $wlbSvcPath,
)
$output = $output -join ","
write-host $output
