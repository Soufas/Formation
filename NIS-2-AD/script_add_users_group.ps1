import-module ActiveDirectory
$Group = Get-ADGroup -Identity "CN=GG-DES-LX-GROVSLCONV,OU=Linux_groups,OU=Groupes,OU=DES-SI,OU=RTE-DES,DC=gr0vsdma,DC=rte-france,DC=com"
Import-CSV "C:\scripts\users.csv" | % {
Add-ADGroupMember -Identity $Group -Member $_.UserName
}