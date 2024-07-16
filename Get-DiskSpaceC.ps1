#lists hostname,date,osversion with patchlevel, free space on C, gateway, and info for last three restarts / poweroffs
#I use this in Scripts in Configuration Manager / SCCM / MEM / MEMCM / whatever
#set your domain here

$domain = "contoso.com"
=========

$output = @()

$d = (Get-Date).GetDateTimeFormats()[65]
$h = hostname
$os = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed\Client.OS.rs2.amd64' -name version
$diskFree = [math]::Round(((Get-PSDrive c).Free/1073741824),4)
$gate = (Get-NetIPConfiguration | where {$_.NetProfile.Name -eq $domain}).IPv4DefaultGateway.NextHop

$output = @($h,$d,$os,$diskFree,$gate)

$numevents = "3"
$t=$u=$m=$null
$e = Get-EventLog system -newest $numevents -Source User32 -InstanceId 2147484722
$e | foreach {
    $m = $_.Message
    $u = ($_.UserName).split('\')[1]
    $t = $_.TimeGenerated.GetDateTimeFormats()[50].tostring()

    #get Shutdown Type
    #add 6 to skip past "Type: "
    $type_msg = $m.IndexOf("Type:")
    $i1 = $type_msg+6
    $comment_msg = $m.IndexOf("Comment:")
    $i2 = $comment_msg-$i1
    $shutdowntype = $m.Substring($i1,$i2)
    $shutdowntype = $shutdowntype.Trim()

    #get Reason Code
    #add 13 to skip past "Reason Code: "
    $reason_msg = $m.IndexOf("Reason Code:")
    $i1 = $reason_msg+13
    $shutdown_msg = $m.IndexOf("Shutdown Type:")
    $i2 = $shutdown_msg-$i1
    $reasoncode = $m.Substring($i1,$i2)
    $reasoncode = $reasoncode.Trim()

    #get Following Reason:
    #add 13 to skip past "Reason Code: "
    $following_msg = $m.IndexOf("following reason:")
    $i1 = $following_msg+18
    #$reason_msg already calculated
    $i2 = $reason_msg-$i1
    $followingreason = $m.Substring($i1,$i2)
    $followingreason = $followingreason.Trim()

    #Write-Host $h","$t","$followingreason","$shutdowntype","$reasoncode","$u
    $output = $output + $t + $shutdowntype + $reasoncode + $u + $followingreason

}

$output = $output -join ","
write-host $output
