#uniquegeek 20250827
#queries connected user sessions using "quser" cmd, 
#but splats info into more useful powershell object instead
#not too fancy with time fields (they are text, not datetime), but that usually is good enough

function quserPS {
    #quser is cmd, not ps
    #but you need to redirect errors to $null, not NUL
    $users = quser 2>$null
    $quserPS = @()
    if ($users.length -gt 0) {
        $date = (Get-Date).ToString()
        $header = $users[0]
        $uIndex = $header.IndexOf("USERNAME")
        $sessionIndex = $header.IndexOf("SESSIONNAME")
        $idIndex = $header.IndexOf("ID ")
        $stateIndex = $header.IndexOf("STATE")
        $idleIndex = $header.IndexOf("IDLE TIME")
        $logonIndex = $header.IndexOf("LOGON TIME")
        if ($users[0].StartsWith(" USERNAME")){
            $users = $users[1..($users.Length-1)]
        }
    
        foreach ($u in $users) {
            #$u = $users[0] #for testing
            $uLength = $u.Length
            $username = $u.substring($uIndex,$sessionIndex-1).trim()
            $session = $u.substring($sessionIndex,$idIndex-4-$sessionIndex).trim()
            $id = $u.substring($idIndex-4,6).trim()
            $state = $u.substring($stateIndex,$idleIndex-$stateIndex).trim()
            $idle = $u.substring($idleIndex,$logonIndex-$idleindex).trim()
            if ($idle -eq ".") {
                $idle = "0:00"
            }
            if ($idle -notmatch ":") {
                if ($idle.Length -eq 1) {
                    $idle = "0:0" + $idle
                } else {
                    $idle = "0:" + $idle
                }
            }
            $logon = $u.substring($logonIndex,$uLength-$logonindex).trim()
            $quserPS +=  @([pscustomobject]@{
                UserName=$username;
                Session=$session;
                ID=$id;
                State=$state;
                IdleTime=$idle;
                LogonTime=$logon
            })
        }   
    }
    $quserPS = $quserPS | Sort-Object UserName
    return $quserPS
}

quserPS | format-table *
#$quserPS | sort IdleTime | ft *
#$quserPS | sort LogonTime -Descending | ft *
