#uniquegeek 20240604
#Allows you to copy a list of computers from SCCM console and restart them only if no one is actually currently logged in
#=== Directions: ===
#copy selection from CM console
#paste in excel
#copy the column of computer names
#paste in $str between the ""
#run the rest of the script

$str = "comp1
comp2
comp3
"

$computers = (([string]::join("=",($str.Split("`n")))) -split "=").trim()
#does not restart if someone is logged in
foreach ($computer in $computers) { 
    if ($computer -ne "") {
        Restart-Computer -AsJob -ComputerName $computer
    }
}
