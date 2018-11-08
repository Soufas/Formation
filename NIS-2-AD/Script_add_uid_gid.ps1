Import-module activedirectory
$ModUsers = import-csv "c:\scripts\users_uid.csv"
foreach ($User in $ModUsers) {
$User.Name
$User.Uid
$User.Gid
#Set-ADUser -Identity $User.Name -add @{gidnumber=$User.Gid ,uidnumber=$User.Uid}
Set-ADUser -Identity $User.Name -replace @{gidnumber = $User.Gid}
Set-ADUser -Identity $User.Name -replace @{uidnumber = $User.Uid}
}