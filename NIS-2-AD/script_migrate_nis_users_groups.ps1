Import-module activedirectory
$ModUsers = import-csv "c:\scripts\to_be_fixed.csv" -Delimiter ";"
foreach($line in $ModUsers){
    $groupe = $line.Group
    $utilisateurs = $line.Users -split ","
    foreach($user in $utilisateurs){
        Add-ADGroupMember -Identity "CN=$groupe,OU=Linux_groups,OU=Groupes,OU=DES-SI,OU=RTE-DES,DC=gr0vsdma,DC=rte-france,DC=com" -Members $user
        # other code which uses $group and $user
    }
}